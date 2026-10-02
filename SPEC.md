# time-log — Specification

A Flutter app for logging what you are doing during the day. One activity runs at a time; starting
a new one stops the current one. The day is shown as a calendar you can read at a glance, resume
past work from, and correct afterwards.

Status: v1 specification. No code yet. Target: Android, iOS, macOS, Windows, Linux, Web.

---

## 1. Purpose and non-goals

### Purpose

Make it effortless to answer "what did I actually do today?" with honest data, by making logging
cheap enough that you keep doing it:

- Starting an activity takes at most two taps from a cold launch.
- You never have to stop something before starting the next thing.
- Mistakes are expected, so correcting a start or end time is a first-class action, not a hidden one.
- The day is a calendar, because a timeline is how people already think about their day.

### Non-goals for v1

| Not in v1 | Why |
| --- | --- |
| Overlapping entries | You do one thing at a time; non-overlap is what makes the calendar and the totals trustworthy. |
| Automatic tracking (app/window/idle detection) | Large platform-specific surface, privacy-sensitive, and it changes the product. |
| Projects, tags, clients, billing, invoicing | Free-text activity names cover personal tracking; structure can be layered on later (§13, P6). |
| Multi-device sync, accounts, sharing | Local-only keeps v1 small and private. The schema does not preclude it (§5.4). |
| Pomodoro, reminders to start, goals, streaks | Different product. Not what is being asked for. |
| Reports beyond per-day and per-week totals | Export exists for anything deeper (§8.6). |

### Principles

1. **The timeline is always valid.** No overlaps, no negative durations, no two running entries —
   enforced at the storage layer, not by UI discipline (§4).
2. **Nothing is destroyed silently.** Every mutation is undoable or soft-deleted.
3. **Every gesture has a non-gesture equivalent.** Anything you can drag, you can also type and
   step with a keyboard or screen reader (§10).
4. **Boring and conventional.** Material 3, standard navigation, standard sheets, standard undo.
   Novel interaction is a cost, not a feature.

---

## 2. User and core loop

One person, their own data, used many times a day in short bursts, often one-handed on a phone and
often while already doing something else.

```
launch ──▶ see what is running ──▶ start the next thing ──▶ (day fills up)
                                        │
   review the day ◀── correct a boundary ◀┘
                │
                └──▶ resume something from earlier
```

The two operations that must be instant are **"start the next thing"** and **"fix that block's
length"**. Everything else can cost a tap more.

---

## 3. Glossary

| Term | Meaning |
| --- | --- |
| **Activity** | A named kind of work ("Writing specs"). Identified by its normalised name. Carries a stable colour. |
| **Entry** | One continuous span of doing an activity: `activityId`, optional note, `startAt`, `endAt`. |
| **Running entry** | The entry with `endAt == null`. At most one exists. Its end is "now". |
| **Gap** | Time between two entries that no entry covers. Legal, and means "untracked". |
| **Boundary** | The instant where an entry starts or ends. **Shared** when two entries touch, **free** when a gap or nothing is on the other side. |
| **Snap** | Rounding applied to times edited by gesture. Default 5 minutes. |
| **Day window** | `[local midnight, next local midnight)`. All day-scoped views and totals use it. |

---

## 4. Timeline invariants

These hold after every committed mutation. They are the specification of correctness, and each one
maps to a named test in §12.

1. **Single running entry.** At most one entry has `endAt == null`.
2. **No overlap.** For any two live entries, their half-open intervals `[startAt, endAt)` do not
   intersect. The running entry is treated as `[startAt, ∞)`.
3. **Positive duration.** `endAt > startAt`, and `endAt - startAt >= 1 minute` for any entry that
   is not running.
4. **Handover is seamless.** When starting B stops A, `A.endAt == B.startAt` exactly — no gap and
   no overlap is introduced by the act of switching.
5. **No future starts.** `startAt <= now` for the running entry. Finished entries may not end in
   the future.
6. **Atomicity.** Every operation in §6 is one transaction that either leaves 1–5 true or changes
   nothing. There is no intermediate state in which the timeline is invalid, including on crash.
7. **Gaps are data, not errors.** Nothing auto-fills a gap. The UI shows gaps; it never hides them
   by stretching neighbours.

Violations of 1–3 are additionally impossible at the SQL level (§5.2); 4–7 are enforced by the
single writer (§11.3).

---

## 5. Data model

### 5.1 Entities

**Activity** — the reusable name. Separate from entries so that a colour stays stable and a rename
applies to all history at once.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid v4 string | |
| `name` | string | As typed, display form. 1–120 chars after trim. |
| `nameKey` | string | Unique. `name` trimmed, whitespace-collapsed, lowercased (Unicode-aware). Matching key for "is this the same activity?". |
| `colorSeed` | int | Index into the palette (§9.7). Assigned on creation from the least-used palette slot; user-editable. |
| `archived` | bool | Hidden from suggestions, kept in history. |
| `createdAt` / `updatedAt` | utc millis | |

**TimeEntry** — one span.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | uuid v4 string | |
| `activityId` | fk → Activity | |
| `note` | string? | Free text, ≤ 2000 chars. What distinguishes two spans of the same activity. |
| `startUtc` | utc millis | |
| `endUtc` | utc millis? | `null` ⇒ running. |
| `tzName` | string | IANA zone captured at creation, e.g. `Europe/Berlin`. See §5.3. |
| `createdAt` / `updatedAt` | utc millis | |
| `deletedAt` | utc millis? | Soft delete. All reads filter `deletedAt IS NULL`. Purged after 30 days. |

**Settings** — single-row table: snap interval, 12/24h, first day of week, theme mode, pixels-per-hour,
long-run threshold, "continue window" (§6.4).

### 5.2 Schema

```sql
CREATE TABLE activities (
  id         TEXT    NOT NULL PRIMARY KEY,
  name       TEXT    NOT NULL,
  name_key   TEXT    NOT NULL UNIQUE,
  color_seed INTEGER NOT NULL,
  archived   INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE time_entries (
  id          TEXT    NOT NULL PRIMARY KEY,
  activity_id TEXT    NOT NULL REFERENCES activities(id),
  note        TEXT,
  start_utc   INTEGER NOT NULL,
  end_utc     INTEGER,
  tz_name     TEXT    NOT NULL,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  deleted_at  INTEGER,
  -- 1 only while this row is the live running entry, NULL otherwise.
  is_running  INTEGER GENERATED ALWAYS AS (
                CASE WHEN end_utc IS NULL AND deleted_at IS NULL THEN 1 END) VIRTUAL,
  CHECK (end_utc IS NULL OR end_utc > start_utc)
);

-- Invariant 1 in the schema: SQLite treats NULLs in a UNIQUE index as distinct,
-- so any number of rows may hold NULL but only one may hold 1.
CREATE UNIQUE INDEX ux_entries_single_running ON time_entries (is_running);
CREATE        INDEX ix_entries_start          ON time_entries (start_utc);
CREATE        INDEX ix_entries_activity_start ON time_entries (activity_id, start_utc);
```

This schema is verified: against SQLite 3.51, inserting a second running entry fails with
`UNIQUE constraint failed: time_entries.is_running`, tombstoning a running row frees the slot, and
`end_utc < start_utc` fails the CHECK.

Non-overlap (invariant 2) has no SQL equivalent — SQLite has no range-exclusion constraint — so it
is enforced inside the single writer's transaction (§11.3), which is also where a debug-mode
assertion re-checks the touched neighbourhood after every write.

### 5.3 Time, zones and DST

- Instants are stored as **UTC epoch milliseconds**. Nothing else is stored as a time.
- `tzName` records where the entry was recorded, so a historical day can be reconstructed as it was
  lived even if you have since moved zones. Rendering uses the **device's current zone** by default;
  "render in recorded zone" is a later option (§13, P6).
- A **day** is `[local midnight, next local midnight)` in the rendering zone — a DST day is 23 or
  25 hours long, and the calendar axis must be built from real instants rather than `hour * 60`
  arithmetic so that the gridlines stay truthful.
- An entry crossing midnight is **one row**. It renders as a clipped segment in each day it touches,
  with a continuation marker (`↑` / `↓`) and a label stating the full span. Day totals count only
  the part inside the day window.

### 5.4 Durability and future-proofing

- `id`s are UUIDs and every row carries `updatedAt` plus soft-delete tombstones. This costs nothing
  now and is what a future sync would need; v1 ships no sync.
- Migrations: Drift schema versions with generated migration steps, plus a committed schema
  snapshot per version and a round-trip migration test from every past version (§12).
- Export/import (§8.6) is the supported backup path and is treated as part of the data model: the
  JSON format carries `schemaVersion` and must remain importable by later app versions.

---

## 6. Actions

Every action below is a method on the single writer (§11.3), is transactional, and emits a
semantics announcement (§10.4) plus — where destructive — an 8-second undo.

### 6.1 Start

Input: activity name (new or existing) + optional note. `startAt = now`.

1. Resolve or create the activity by `nameKey`.
2. If an entry is running, set its `endUtc = now` — the same instant used as the new entry's start
   (invariant 4).
3. Insert the new running entry.

Edge cases:
- Starting the activity that is *already* running is a no-op with a "already running" message; it
  does not split the entry.
- If the running entry would be left shorter than 1 minute by the handover, the handover instead
  **replaces** it: the <1-minute entry is deleted and the new one takes its start time. Rationale:
  a mistaken start corrected three seconds later should not litter the timeline. Undo restores both.

### 6.2 Stop

Set `endUtc = now` on the running entry. If the result would be under 1 minute, offer
"discard instead" in the confirmation SnackBar rather than silently keeping or deleting it.

### 6.3 Resume

From any entry (its sheet, its long-press menu, a history row): **start a new entry** with the same
activity and note, beginning now. The source entry is not modified. This is the primary way to pick
work back up, and it is deliberately a copy, not an edit — history keeps both spans.

### 6.4 Continue (extend instead of duplicate)

If the entry being resumed is the **most recent** one and it ended **within the continue window**
(default 5 minutes, settable 0–30, 0 = off) and nothing is running, the resume affordance offers two
choices with "Continue" preselected:

- **Continue** — reopen that entry (`endUtc = null`), absorbing the short gap.
- **Start new** — the §6.3 behaviour.

Reopening is only legal while the entry is still the last one and nothing is running; otherwise the
choice is not offered.

### 6.5 Edit times

Change `startAt` and/or `endAt` of any finished entry, or the `startAt` of the running entry, by the
boundary rules in §7. Available as drag, as typed time fields, and as ± steppers.

### 6.6 Split

Split one entry at a chosen instant into two entries with the same activity and note, sharing a
boundary. Used to retro-label "I was actually doing two things there". The second half's activity
can be changed immediately in the sheet that opens.

### 6.7 Rename, recolour, merge

Renaming an activity to a `nameKey` that already exists offers **merge** (re-point all entries,
delete the empty activity). Both are undoable. Recolouring picks from the palette (§9.7).

### 6.8 Delete

Soft delete with undo. Deleting an entry leaves a gap — neighbours are never stretched (invariant 7).

---

## 7. Boundary editing rules

The one genuinely ambiguous part of the app, so it is pinned down here. These rules apply
identically to drag, typed fields and steppers.

### 7.1 Shared vs free boundaries

- **Shared boundary** (two entries touch, `A.endAt == B.startAt`): moving it moves **both** edges.
  A grows while B shrinks, or vice versa. Total tracked time is conserved, no gap appears. This is
  the behaviour of adjacent events in Google Calendar and of Toggl's timeline, and it is what "I
  switched at 14:30, not 14:15" means.
- **Free boundary** (a gap, or nothing, on the other side): moving it moves **that edge only**,
  growing into or shrinking away from the gap.

### 7.2 Clamping

A boundary can never cross:
- the far edge of its own entry, minus the 1-minute minimum;
- the far edge of the neighbour it shares with, minus that neighbour's 1-minute minimum;
- `now`, for anything that would end in the future.

Clamping is silent: the block simply stops following the finger, with a short haptic at the limit.
The app does not throw an error for a gesture that was merely over-eager. **Typed** input that
violates a clamp *is* reported, inline, naming the conflict ("overlaps *Email* until 15:05").

### 7.3 Snapping

Gesture edits snap to the snap interval (default 5 min; 1 / 5 / 15 / off). Typed edits do not snap.
Snapping applies to the resulting instant, not to the delta, so a block edited twice does not drift.

### 7.4 The running entry

Its end is "now" and is not editable; the bottom of the running block has no drag handle. Its start
is editable like any other free or shared boundary.

### 7.5 Undo

Every committed boundary change pushes one undo step covering **all** edges it moved (a shared-
boundary drag is one step, not two). SnackBar with "Undo", 8 seconds, and the action remains in the
sheet's overflow menu for the rest of the session.

---

## 8. Screens

Navigation: `Today` / `History` / `Settings`. Bottom navigation bar on phones, navigation rail from
the medium breakpoint (≥ 600 dp), extended rail on desktop (≥ 1240 dp). `go_router` with deep links
`/` , `/day/:isoDate`, `/entry/:id`, `/history`, `/settings`.

### 8.1 Today (home)

The default screen, and the one optimised to death.

- **Running card**, pinned at the top: activity name, note, start time, elapsed time (ticking at
  1 s, `MM:SS` under an hour then `H:MM:SS`), and a **Stop** button. When nothing runs, the card
  collapses to a single "Nothing is running" line plus **Resume *last activity***.
- **Start** — a `FloatingActionButton.extended` labelled "Start", bottom-right, above the nav bar.
  Opens §8.3. This plus one tap in the sheet is the two-tap target.
- **Body**: the day calendar for today (§8.2).
- **Footer**: tracked total for the day, untracked total, and the top three activities by time.
- **Long-run banner**: if the running entry exceeds the long-run threshold (default 8 h), a
  non-blocking banner — "Still tracking *X* after 8 h?" — with **Stop at…** (time picker) and
  **Keep going**. Never a modal, never a notification you cannot dismiss.

### 8.2 Day calendar view

- Vertical axis, hour rules with labels, half-hour hairlines above 100 px/hour.
- **Zoom** 40–240 px/hour, default 72 (a 24-hour day scrolls). Pinch on touch, `Ctrl`/`Cmd`+scroll
  on desktop, and explicit zoom buttons for anyone who cannot pinch.
- **Now-line**: 2 px accent line with a time pill on the axis; the running block extends to it.
  Updates every 30 s, and on app resume. Static (no pulse) when animations are disabled.
- **Blocks**: activity colour, name, time range and duration as text. Minimum rendered height 18 px
  so short entries stay visible and hittable; labels drop out progressively (duration first, then
  name) and the full text stays in the semantics label and the sheet. Where several sub-snap entries
  would collide visually, they render as one "*n* short entries" chip that expands on tap or zoom.
- **Gaps**: untracked ranges over 5 minutes are shown as a hatched area labelled with their length,
  tappable to create an entry filling exactly that gap.
- **Day navigation**: horizontal swipe, `←`/`→`, a date header that opens a date picker, and a
  **Today** action that is only enabled when you are not on today.
- On first open the view scrolls to show the now-line, or the day's first entry for past days.
- Empty state: "No entries for this day" plus **Start** / **Add entry**.

### 8.3 Start sheet

A bottom sheet (dialog on desktop) that is keyboard-first:

- Text field with focus and keyboard up on open. Enter starts; Escape cancels.
- **Suggestions** below the field: recent/frequent activities (§9.6), as a vertical list of rows
  (name, colour, "last: 2 h ago"), filtered as you type. Arrow keys move, Enter picks.
- An explicit consequence line when something is running: "Stops **Writing specs** at 14:32." This
  is the only warning; there is no confirmation dialog, because Undo covers it.
- Optional note field, collapsed behind "Add note".
- If the typed name is new: "Create **Deep work**" as the first row, so creation is never a mode.

### 8.4 Entry sheet (detail / edit)

Opened by tapping any block or history row. Contents, in order:

1. Activity name (tap to change or rename), colour swatch, note (inline-editable).
2. **Start**, **End**, **Duration** — three fields that stay consistent: editing any two updates the
   third (editing duration moves `endAt`, or `startAt` for a boundary pinned by §7). Each has a
   time-picker affordance **and** `−`/`+` stepper buttons of one snap interval.
3. Conflict text inline when a typed value breaks a clamp (§7.2).
4. Actions: **Resume** (or **Continue**, §6.4) · **Split here…** · **Delete**.
5. For the running entry: **Stop** replaces the End field, which reads "running".

### 8.5 History

Reverse-chronological list grouped by day with sticky day headers and per-day totals; each row shows
colour, name, range, duration, and **Resume**. Search by activity name and note text. Filter by
activity. Lazy-loads by month. Swipe a row to delete (with undo); long-press for the context menu.

### 8.6 Settings

- Snap interval · 12/24-hour · first day of week · theme (system/light/dark) · default zoom.
- Continue window (§6.4) · long-run threshold.
- **Export**: JSON (full fidelity: `schemaVersion`, activities, entries, settings) and CSV
  (`id, activity, note, start_local, end_local, start_utc, end_utc, duration_minutes, tz`). Shared
  via the platform share sheet / save dialog; downloaded on web.
- **Import**: JSON only. Merge by `id`, newest `updatedAt` wins; shows a dry-run summary (added /
  updated / skipped / rejected) before applying, and rejects any file that would break §4, naming
  the first offending pair.
- **Delete all data**, with typed confirmation.
- About: version, licences, link to this spec.

---

## 9. Behaviour details

### 9.1 Persistence of the running state

A running entry is nothing but a stored `startUtc`. Elapsed time is always computed as
`now - startUtc` at read time; no timer accumulates state. Therefore app kill, OS kill, reboot,
device sleep, and clock-zone changes need **no** recovery code, and there is no background service,
no foreground service requirement, and no doze-mode problem. The UI timer is a pure display concern.

### 9.2 Clock jumps

If the wall clock moves backwards such that `now < runningEntry.startUtc`, the running card shows
"started in the future" with **Fix start time…** instead of a negative duration. Durations are
otherwise never rendered negative or as `--`.

### 9.3 Lifecycle

On resume: re-read the clock, re-render the now-line, re-run the long-run check. No reconciliation
pass is needed (§9.1).

### 9.4 Performance budgets

| Thing | Budget |
| --- | --- |
| Cold start to interactive | < 1.5 s on a mid-range Android device |
| Start action, tap to committed | < 50 ms |
| One day's entries query at 50 000 entries | < 5 ms |
| Calendar scroll / zoom | no dropped frames at the device refresh rate |
| Day view rebuild on timer tick | only the now-line and running block repaint |

### 9.5 Error and edge states

- DB fails to open: full-screen explanation with **Retry** and **Export diagnostics**; never a
  silent empty timeline, which would read as data loss.
- Web without persistent storage (private browsing, no OPFS): a dismissible banner — "Storage here
  is temporary. Export to keep your data." — shown on first launch and in Settings.
- Import of a file from a newer `schemaVersion`: refused with a clear message, never partially applied.

### 9.6 Suggestion ranking

For each non-archived activity, over the last 90 days:

```
score = Σ over its entries of 0.5 ^ (ageInDays / 7)      // 7-day half-life
```

so frequency and recency both count and neither dominates. While typing, rows whose `nameKey`
*starts with* the query are boosted above substring matches; ties break on most-recent use. The
currently running activity is excluded. With no history, the list is empty and the field explains
"Type what you are doing".

### 9.7 Colour

A 12-colour palette, each entry tested for ≥ 4.5:1 contrast against its own on-colour in both light
and dark theme. New activities take the least-used slot. Colour is always accompanied by the name in
text — it is never the only way to tell two blocks apart (§10.3).

---

## 10. Accessibility requirements

Target **WCAG 2.2 AA**. These are acceptance criteria for every phase, not a late polish pass; a
feature that fails them is not done.

### 10.1 No gesture-only functionality

| Gesture | Equivalent |
| --- | --- |
| Drag block edge to resize | Entry sheet Start/End/Duration fields + `−`/`+` steppers; `onIncrease`/`onDecrease` semantics actions on the block; keyboard shortcuts (§10.5) |
| Pinch to zoom | Zoom buttons; `Ctrl`/`Cmd`+scroll; a zoom setting |
| Swipe between days | `←`/`→`, date header picker, Today action |
| Swipe row to delete | Long-press context menu; sheet action |

### 10.2 Targets, text and motion

- All interactive targets ≥ 48 × 48 dp, including resize handles (which sit as pucks partly outside
  short blocks to reach the size) and the stepper buttons.
- Layout survives text scale to 200 % and bold-text settings: no clipped labels, no overlapping
  rows; blocks drop labels rather than truncating mid-word, and the sheet scrolls.
- `MediaQuery.disableAnimations` is honoured: no now-line pulse, no block-resize animation,
  instant sheet transitions.

### 10.3 Colour and contrast

- Text on blocks ≥ 4.5:1 against its block colour in both themes; the now-line and focus ring ≥ 3:1.
- Activity identity is conveyed by name text everywhere, never by colour alone. Running state is
  conveyed by the word "running" in the semantics label and a visible "Running" chip.
- Verified under grayscale and a deuteranopia simulation as part of review.

### 10.4 Screen readers

- Block semantics: label `"<name>, 14:00 to 15:30, 1 hour 30 minutes"`; hint
  `"Double tap to edit"`; `increasedValue`/`decreasedValue` describing the snap step; the running
  block appends `", running"`.
- Gaps: `"Untracked, 12:10 to 12:35, 25 minutes. Double tap to add an entry."`
- `SemanticsService.announce` on start, stop, resume, continue, delete, undo, and every committed
  boundary change ("*Email* now ends at 15:05").
- **The ticking elapsed counter is not a live region.** It is labelled coarsely (`"running, 1 hour
  12 minutes"`) and read on demand; a per-second live region would make the screen unusable.
- Day view is traversable in chronological order; the day header announces the date and totals.
- Reading order and focus order match visual order; sheets trap focus and return it on dismiss.

### 10.5 Keyboard

Global: `Cmd/Ctrl+N` start · `Cmd/Ctrl+.` stop · `Cmd/Ctrl+R` resume last · `Cmd/Ctrl+F` search ·
`T` today · `←`/`→` previous/next day · `?` shortcut sheet.

With a block focused: `Enter` open sheet · `Space` resume · `Delete` delete ·
`Shift+↑`/`Shift+↓` move the **end** by one snap · `Alt+↑`/`Alt+↓` move the **start** by one snap ·
`Cmd/Ctrl+Z` undo. Every shortcut is listed in the `?` sheet and in Settings.

### 10.6 Verification

Automated: `flutter test` semantics assertions on every interactive widget, a golden-test pass at
200 % text scale, and a check that no widget tree has an unlabelled tappable. Manual, per release:
TalkBack, VoiceOver, keyboard-only desktop pass, and a 200 %-scale pass. Recorded in §14.

---

## 11. Architecture

### 11.1 Stack

| Concern | Choice | Version |
| --- | --- | --- |
| SDK | Flutter / Dart | 3.47 / 3.13 |
| UI | Material 3, `ThemeData.useMaterial3` | — |
| State | `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` | ^3.4.3 / ^4.0.7 / ^4.0.9 |
| Persistence | `drift` + `drift_flutter` (SQLite; `WasmDatabase` + OPFS on web) | ^2.35.1 / ^0.3.1 |
| Routing | `go_router` | ^18.0.2 |
| Formatting | `intl` | ^0.20.3 |
| Zones | `timezone` + `flutter_timezone` | ^0.11.1 / ^5.1.0 |
| IDs | `uuid` | ^4.6.0 |
| Time injection | `clock` | ^1.1.3 |
| Codegen | `build_runner`, `drift_dev` | ^2.16.1 / ^2.35.1 |
| Tests | `flutter_test`, `integration_test`, `mocktail` | — / — / ^1.0.5 |

Notes: `drift_flutter` brings the native SQLite libraries and `path_provider` transitively — do
**not** add `sqlite3_flutter_libs` directly, it is now EOL (`sqlite3` 3.x bundles the natives).
Web requires the `sqlite3.wasm` and drift worker assets to be committed under `web/`.
Platform-affordance packages (`flutter_local_notifications`, `share_plus`, `file_picker`) arrive with
the phases that need them (§13), not in P0.

### 11.2 Layout

```
lib/
  main.dart
  src/
    app/            app widget, router, theme, localisation
    core/           clock, result/failure types, extensions, formatters, palette
    data/
      db/           drift tables, database, migrations, schema snapshots
      repositories/ entry + activity + settings repositories (stream queries)
    domain/
      models/       Activity, TimeEntry, DayTimeline, Gap  (immutable, pure Dart)
      timeline/     invariants, boundary math, snapping, day-splitting  (pure, no Flutter)
      timeline_writer.dart
    features/
      today/        running card, day calendar, start sheet
      entry/        entry sheet, split
      history/      list, search
      settings/     settings, export, import
test/               mirrors lib/src
integration_test/
```

`domain/timeline/` is pure Dart with no Flutter or Drift import — all boundary arithmetic, clamping,
snapping, midnight-splitting and gap computation live there and are unit-testable without a database
or a widget tree. This is where the hard logic goes.

### 11.3 The single writer

`TimelineWriter` is the **only** thing that mutates entries. Every method from §6 is one method
here, each wrapped in a Drift transaction that:

1. reads the affected neighbourhood (predecessor, successor, running entry);
2. computes the new state with the pure functions in `domain/timeline/`;
3. validates §4 against the neighbourhood and fails the transaction on violation;
4. writes, bumping `updatedAt`;
5. returns an `UndoToken` describing the inverse operation.

No repository or widget writes to `time_entries` directly; a test asserts this (§12). Reads go
through repositories that expose Drift `watch` streams, so the UI is reactive and there is no manual
invalidation.

### 11.4 Time injection

All code takes time from an injected `Clock` (`clock` package) provided by Riverpod, never
`DateTime.now()`. A lint-grep test fails the build if `DateTime.now()` appears outside
`core/clock.dart`. This is what makes §4, §7 and DST behaviour testable.

---

## 12. Testing strategy

**Unit — invariants (§4).** One named test each, all against a fake clock:
`startingWhileRunningLeavesNoGap` · `onlyOneRunningEntryEverExists` ·
`concurrentStartsDoNotCreateTwoRunning` · `noEntryOverlapsAnother` · `endIsAlwaysAfterStart` ·
`subMinuteHandoverReplacesInsteadOfSplitting` · `failedMutationChangesNothing` ·
`deleteLeavesGapAndDoesNotStretchNeighbours`.

**Unit — boundary math (§7).** `draggingSharedBoundaryConservesTotalTrackedTime` ·
`draggingFreeEdgeGrowsIntoGapOnly` · `clampStopsAtNeighbourMinusMinimum` ·
`snapRoundsInstantNotDelta` · `repeatedEditsDoNotDrift` · `runningEntryEndIsNotEditable` ·
`typedOverlapIsRejectedWithNamedConflict`.

**Unit — day/zone logic (§5.3).** `entryCrossingMidnightRendersInBothDays` ·
`dayTotalsClipToDayWindow` · `dstShortDayHas23HourAxis` · `dstLongDayHas25HourAxis` ·
`dayWindowFollowsRenderingZone`.

**Unit — suggestions (§9.6).** `recentBeatsFrequentWithinHalfLife` · `prefixMatchOutranksSubstring` ·
`runningActivityIsExcluded`.

**Widget.** Running card states (idle / running / future-start) · calendar geometry (block position
and height for a given zoom, short-entry minimum, gap rendering) · start sheet keyboard flow ·
entry-sheet three-field consistency · semantics labels and actions on blocks, gaps and steppers ·
golden tests at 1.0× and 2.0× text scale in light and dark.

**Integration (`integration_test`).** The core loop on a real DB: start A → start B → verify
handover instant → resume A → correct a boundary by drag → undo → kill and relaunch the app →
running entry survives with correct elapsed time. Plus export → wipe → import → timeline identical.

**Migration.** Drift schema snapshots per version, with a test migrating from every past version to
current and asserting §4 still holds.

**Architecture.** `timelineWriterIsTheOnlyWriter` (grep for `time_entries` updates outside it) ·
`noDateTimeNowOutsideClock` (§11.4) · `domainHasNoFlutterImports`.

CI runs `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`, and the
integration suite on one mobile and one desktop target.

---

## 13. Build phases

| Phase | Scope | Done when |
| --- | --- | --- |
| **P0 Foundation** | `flutter create` for all six targets, deps, folder layout, Drift DB + schema (§5.2) + migration harness, `Clock`, Riverpod wiring, M3 theme + palette, router skeleton, CI. | App launches on phone, desktop and web against an empty DB; invariant tests exist and pass against the writer's stubs. |
| **P1 Core tracking** | `TimelineWriter` start/stop/resume/continue, running card, Start sheet with suggestions, persistence across relaunch. | Start → switch → resume works end-to-end; §4 and §6 tests green; running entry survives app kill. |
| **P2 Day calendar** | Day view, axis, zoom, now-line, blocks, gaps, midnight splitting, day navigation, day totals. | Calendar geometry and day/zone tests green; a day of real use reads correctly, including across a DST change. |
| **P3 Editing** | Drag handles, the §7 rules, entry sheet with typed fields and steppers, split, delete, undo — each landing with its keyboard and screen-reader equivalent. | §7 tests green; a boundary can be corrected by drag, by typing, and by keyboard alone with identical results. |
| **P4 Daily usability** | History + search, export/import, settings, long-run banner, short-entry clustering, empty/error states. | Export → wipe → import round-trips; §10.6 manual passes done. |
| **P5 Platform affordances** | Android persistent notification with Stop/Resume actions, iOS Live Activity (best-effort), desktop global shortcuts + menubar/tray quick-start, web install/PWA polish. | Start and stop are reachable without opening the app on each platform that supports it. |
| **P6 Later** | Week view, per-activity reports, render-in-recorded-zone, projects/tags, optional sync. | Out of v1 scope; listed so the v1 model does not preclude them. |

Each phase ends with: `flutter analyze` clean, tests green, a11y criteria in §10 met for the new
surface, and the spec updated if the phase taught us something.

---

## 14. Acceptance criteria for v1

1. From a cold launch, starting a new activity takes **two taps** (FAB → suggestion row).
2. Starting an activity while another runs leaves **no gap and no overlap**, verified by test.
3. At most one entry runs at a time, enforced by a UNIQUE index and verified by test.
4. A running entry survives app kill, OS kill and reboot with the correct elapsed time, and needs no
   background service.
5. Any entry's start or end can be corrected by **drag**, by **typing**, and by **keyboard only**,
   with identical results and a working undo.
6. Dragging a shared boundary conserves total tracked time; dragging a free edge changes only that
   entry's length.
7. Any past entry can be resumed in one action, and extending the most recent one is offered instead
   of a duplicate when it ended within the continue window.
8. The day calendar renders a 23-hour and a 25-hour DST day, and a midnight-crossing entry, correctly.
9. All of §10 holds: TalkBack, VoiceOver and keyboard-only passes done; 200 % text scale clean;
   contrast verified; no gesture-only functionality.
10. Full data export and re-import round-trips to an identical timeline.
11. Performance budgets in §9.4 met on a mid-range Android device with 50 000 seeded entries.
12. The app runs on Android, iOS, macOS, Windows, Linux and Web from one codebase, with no feature
    silently missing on a platform (anything platform-gated is stated in the UI).

---

## 15. Requirement traceability

The original request, mapped to where it is specified:

| Request | Specified in |
| --- | --- |
| Flutter app to track what I am doing | §1, §11.1 |
| Daily calendar view showing the logs | §8.1, §8.2, §5.3 |
| Really easy to use | §1 principles, §2, §8.1 (two-tap start), §9.4 |
| Accessible | §10 in full, §14.9 |
| Common UX patterns | §8 (M3, bottom nav/rail, sheets, FAB, SnackBar undo), §7.1 (calendar-standard boundaries) |
| Starting an action stops the current one | §4.1, §4.4, §6.1 |
| Log a start and a stop time | §5.1, §6.1, §6.2 |
| Resume an existing log as a new entry | §6.3, §6.4, §8.4, §8.5 |
| Change entry length afterwards to fix errors | §6.5, §7 in full, §8.4, §14.5 |

---

## 16. Open questions

1. **Gap behaviour on delete** — v1 leaves a gap (invariant 7). If in real use deleting a mis-start
   usually means "give that time back to the neighbour", an opt-in "close the gap" action on delete
   is the smallest fix. Revisit after a week of P4 use.
2. **Continue window default** — 5 minutes is a guess. Instrument nothing; just see whether it feels
   right in P4 and change the default.
3. **Notes vs. activity names** — if notes end up carrying the real distinctions, that is the signal
   that tags (P6) are actually needed.
4. **App name and bundle identifier** — needed before P5 (store-facing). Currently `time_log`.
