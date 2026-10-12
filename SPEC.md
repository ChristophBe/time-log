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

- The start input is on screen at all times, so starting is one tap or one line typed — there is
  nothing to open first, from a cold launch or from anywhere else.
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
4. **Boring and conventional — on whichever platform you are.** Standard navigation, standard
   sheets, standard undo, and the host's own manners: Material on Android, Liquid Glass on Apple,
   Fluent's density on Windows, GNOME's shapes on Linux. Novel interaction is a cost, not a feature,
   and so is making a user learn a design system their device does not use. What does *not* adapt is
   the identity — colour meaning, typeface, the mark, the day's own shapes (§9.8).

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
| **Day rollover** | Stopping the running entry at a local midnight and restarting it there, so no running entry spans two days (§6.11). |

---

## 4. Timeline invariants

These hold after every committed mutation. They are the specification of correctness, and each one
maps to a named test in §12.

1. **Single running entry.** At most one entry has `endAt == null`.
2. **No overlap.** For any two live entries, their half-open intervals `[startAt, endAt)` do not
   intersect. The running entry is treated as `[startAt, ∞)`.
3. **Positive duration.** `endAt > startAt` for every finished entry. The **one-minute minimum is a
   constraint on editing**, not on storage (§7.2): a genuinely 20-second span recorded by Stop is
   kept exactly as it happened, because rounding it up to a minute would record time that did not
   occur. The minimum exists so dragging cannot produce degenerate, unhittable blocks.
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
- A **finished** entry crossing midnight is **one row**. It renders as a clipped segment in each day
  it touches, with a continuation marker (`↑` / `↓`) and a label stating the full span. Day totals
  count only the part inside the day window.
- The **running** entry never crosses midnight: §6.11 stops it at the boundary and restarts it there.
  The clipping above still has to exist all the same, because typing (§8.4), dragging (§7), filling a
  gap (§8.2) and importing (§8.6) can each record a *finished* span across the date line.

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

Set `endUtc = now` on the running entry — exactly now, never rounded. If the span came out under a
minute the entry is still kept, and the confirmation SnackBar offers **Discard** in place of Undo,
since at that length the likelier intent is "that was a mistake".

This is deliberately *not* the same as §6.1's handling of an immediate switch. Switching within a
minute says "I mis-started and the real activity is this other one", so the mis-start is replaced.
Stopping within a minute says "that is what I did", so it is recorded and you are offered the
discard.

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

### 6.9 Edit note

Replaces one entry's note (≤ 2000 chars; empty or blank is stored as `null`, so "has a note" stays
one question and clearing one survives an export round-trip). One transaction, one undo token. One
of the two actions here that do not re-check §4 (the other is §6.10): a note touches no instant and
no running slot, so there is nothing it can invalidate.

### 6.10 Change an entry's activity

Re-points **one** entry at a different activity. The name is resolved or created by `nameKey`
exactly as §6.1 does, so creating is never a mode: typing a name nothing matches makes it, with a
colour from the least-used palette slot. One transaction, one undo token.

`startAt`, `endAt` and the note are untouched. This is the retro-labelling action — "that hour was
Email, not Writing specs" — and it is the fix for a mis-start noticed too late for §6.1's
sub-minute replacement to have caught it.

Not to be confused with §6.7, and the one pair in the app where the confusion would be expensive:

- **§6.10 changes which activity one span belongs to.** Nothing else moves.
- **§6.7 changes the activity itself**, and therefore every entry that has ever used it.

So they share one affordance — the activity name in the entry sheet (§8.4) — with this action
primary and §6.7 demoted inside it and labelled as the all-history one.

Edge cases:
- Picking the activity the entry already has is a no-op: nothing is written and no undo is offered.
- Legal on the running entry. Relabelling it does not stop it, start anything, or move its start.
- A relabel can leave two **touching** entries that share an activity. They stay two entries:
  nothing is merged and no note is absorbed (§16.6).

Like §6.9 this re-checks no §4 invariant, for the same reason: an activity id is not an instant and
is not the running slot, so there is nothing it can invalidate. Undo restores the entry's previous
activity, and drops an activity this action created if no entry is left pointing at it.

### 6.11 Day rollover

The one action nobody performs. It happens to a clock left running: when the running entry has
crossed a local midnight, it is **stopped at that midnight and restarted there**. A night shift then
reads as 22:00–24:00 yesterday and 00:00–now today, and every day owns its own entries, instead of
one span draped over the date line and clipped differently by every view that touches it.

1. Read the running entry. If nothing is running, nothing happens.
2. Compute the local midnights strictly after its start and at or before now, from §5.3's day
   windows — so a DST day is still 23 or 25 hours long and the cut lands on the real boundary.
3. For each of them, oldest first: set the current entry's `endUtc` to that midnight, then insert a
   new running entry beginning at the same instant with the same activity and note.

The cut instant is shared exactly, so this is §4.4's seamless handover and introduces neither a gap
nor an overlap. It is also necessarily **retroactive**: §4.5 forbids an end in the future, so a
midnight cannot be written before it has passed. This is therefore a catch-up pass — run at launch,
on resume, and on the 30-second tick (§9.3) — and not an alarm set for 00:00. Because the instants
it records are the midnights themselves, *when* it is noticed makes no difference to the data.

Only the **running** entry is cut. A finished entry that crosses midnight stays one row and is
rendered in both days (§5.3). The difference is who chose the span: a typed, dragged, gap-filled or
imported entry was recorded across midnight by someone who said so, whereas the running entry has no
end yet, which makes it the one case where the app picks the boundary rather than honouring one.

Edge cases:
- **Several midnights at once.** The app can be shut for days with the clock running, so every
  boundary is backfilled: a Friday-evening start reopened on Monday leaves one entry per whole day
  plus a running one for today, rather than a single 62-hour span.
- **A sub-minute scrap before midnight.** Starting at 23:59:40 leaves 20 seconds on the old day, and
  they are kept. §4.3's minimum is a constraint on editing and not on storage, and taking those 20
  seconds off the day's total would erase time that did happen — §6.2's reasoning exactly.
- **Not undoable.** Every other action here returns an undo token because a person pressed
  something. This one runs by itself, and an Undo button appearing unprompted at midnight would be
  noise. Both halves are ordinary entries afterwards and can be edited like any others.
- **Idempotent, and self-healing.** Running the pass again writes nothing. If a spanning running
  entry reappears — §6.4 reopening an entry that ended at a midnight, or §8.6 importing one — the
  next pass cuts it again.
- **A run older than a year** is a forgotten clock, not a year of work. Past 366 boundaries the pass
  closes the entry at the first midnight and does *not* restart it, so the app comes back with
  nothing running rather than with 400 invented days.

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
- This distinction belongs to the **boundary, not to the gesture**. A typed time and a stepper nudge
  carry the neighbour exactly as a drag does. Without that, typing could never move a shared
  boundary at all — every value would be reported as overlapping the neighbour — and the three
  editing paths of §14.5 would disagree.

### 7.2 Clamping

A boundary can never cross:
- the far edge of its own entry, minus the 1-minute minimum;
- the far edge of the neighbour it shares with, minus that neighbour's 1-minute minimum;
- `now`, for anything that would end in the future.

Clamping is silent: the block simply stops following the finger, with a short haptic at the limit.
The app does not throw an error for a gesture that was merely over-eager. **Typed** input that
violates a clamp *is* reported, inline, naming the conflict ("overlaps *Email* until 15:05", or for a
shared boundary, "that would leave *Email* under 1 minute").

A drag keeps the **grab offset**: the boundary moves by as much as the finger moves, rather than
jumping to wherever the finger first landed. Grabbing an edge should not itself change anything.

### 7.3 Snapping

Gesture edits snap to the snap interval (default 5 min; 1 / 5 / 15 / off). Typed edits do not snap.
Snapping applies to the resulting instant, not to the delta, so a block edited twice does not drift.

### 7.4 The running entry

Its end is "now" and is not editable; the bottom of the running block has no drag handle. Its start
is editable like any other free or shared boundary.

The entry *before* it is editable in full, including the boundary the two share, which moves both
edges exactly as §7.1 says any shared boundary does. Only the running entry's own end is special,
and only because "now" is not a value anyone gets to choose — the entry that just finished is the
one most likely to need correcting, and §14.5 applies to it like everything else.

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

Three zones, top to bottom: the **day header**, the **day**, the **start composer**. The two
outer ones are chrome and share one container tone; the day between them keeps the plain surface.
There is no app bar — a band whose only contents are a fixed title and one icon is chrome that
tells you nothing, and the date is the real title of this screen.

- **Day header**, two rows on one surface:
  - the date (tap for the date picker), the day's tracked total beside it, then previous / next
    day, **Today**, and **Settings** (§8.2);
  - the **running band**: activity name, start time, note, elapsed time (ticking at 1 s, `MM:SS`
    under an hour then `H:MM:SS`), and a **Stop** button. It carries the running activity's own
    tint and its coloured edge — the same colour its block has on the calendar below. When nothing
    runs it reads "Nothing is running" plus **Resume *last activity***; when the clock has jumped
    it carries the §9.2 explanation. **All three states are the same height**, so the header does
    not resize under your finger the instant you start or stop something. Past about 140 % text
    scale the band stacks instead of ellipsizing every part of itself.
- **Start composer**, docked to the bottom edge and on screen at all times (§8.3): a text field and
  a **Start** button. There is no FAB and no sheet. The app has one primary verb, so the control
  that performs it sits in the open rather than behind a button that opens a modal containing it,
  and the bottom edge is reserved for it because it is the one control that has to be reachable with
  a thumb at any moment.
- **Body**: the day calendar for today (§8.2).
- **Day total**: the tracked total for the day, next to the date in the header (§8.2),
  rather than a footer — the bottom edge belongs to the composer. It is the one number worth reading
  at a glance; untracked time is already visible as gaps in the calendar, and per-activity totals are
  a report (§8.6), not a thing to carry on the home screen. §10.4 already asked the day header to
  announce the date and the total, so this also makes the screen agree with a rule the footer
  arrangement was quietly failing.
- **Long-run banner**: if the running entry exceeds the long-run threshold (default 8 h), a
  non-blocking banner — "Still tracking *X* after 8 h?" — with **Stop at…** (time picker) and
  **Keep going**. Never a modal, never a notification you cannot dismiss. The threshold is measured
  over the **whole run**, following back through the entries §6.11 cut at midnight — otherwise the
  one case the banner exists for, a clock left on overnight, would be the one case that never asks,
  because the rollover had just handed it a fresh entry. **Keep going** likewise stays pressed across
  a cut rather than returning at 00:00.

### 8.2 Day calendar view

- Vertical axis, hour rules with labels, half-hour hairlines above 100 px/hour. The rules are
  painted, not laid out per hour: a row per tick centres its hairline inside its own text height,
  which puts every gridline below the instant it claims to mark while the blocks beside it are
  positioned exactly. Labels sit in the gutter, which the rules stop short of, and a vertical
  hairline closes the gutter so the blocks read as placed against the axis.
- **Zoom** 40–240 px/hour, default 72 (a 24-hour day scrolls). Pinch on touch, `Ctrl`/`Cmd`+scroll
  on desktop, and explicit zoom buttons for anyone who cannot pinch. The buttons float over the
  top-right of the day rather than sitting in the header: zoom acts on what is underneath it, and
  the header is for the day, not for the view of it. They are always on screen — they are the
  non-gesture equivalent of pinching (§10.1), so they may not live behind a menu.
- **Now-line**: 2 px line in the app's accent — not the error colour, because nothing is wrong at
  15:04 — with a time pill on the axis and a dot where it leaves the gutter. The line is **centred on
  the instant**: it lives at the vertical centre of the row carrying the pill, so that row is lifted
  by half its own height rather than positioned by its top, which used to draw it some nine pixels
  into the future.
- **The running entry is drawn unfinished.** Its bottom edge meets the now-line exactly and its
  bottom corners are square — a rounded cap a pixel clear of the line says the entry ended there.
  It is also the one block pinned by its *bottom*: an entry started a minute ago is still drawn at
  the 18 px minimum, but that minimum is spent upwards, because spending it downwards would paint
  time that has not happened yet. The same treatment covers an edge clipped by midnight: a cut edge
  is not a cap.
  Updates every 30 s, and on app resume. Static (no pulse) when animations are disabled.
- **Blocks**: the activity's fill, its coloured edge as a spine down the left, name, time range and
  duration as text. The spine does the work a border used to: two touching blocks of similar hue
  stay told apart by their edges rather than by an outline drawn round everything. Minimum rendered
  height 18 px so short entries stay visible and hittable; labels drop out progressively (duration
  first, then name) when the block is shorter than the lines themselves need **at the reader's text
  scale**, and the full text stays in the semantics label and the sheet. A selected or focused block
  shows grab pucks on its edges; they are decoration, and the drag targets remain the whole top and
  bottom halves. Where several sub-snap entries
  would collide visually, they render as one "*n* short entries" chip that expands on tap or zoom.
- **Gaps**: untracked ranges over 5 minutes are shown as a shallow recess under a sparse hatch,
  labelled with their length, tappable to create an entry filling exactly that gap. Quiet on
  purpose: a hatch at the weight of the hour rules makes every gap the loudest thing on the day.
- **Day navigation**, in the header's first row (§8.1): horizontal swipe, `←`/`→`, the date itself
  opens a date picker, a **Today** action that is only enabled when you are not on today, and the
  day's tracked total beside the date.
- **The day follows midnight.** If the day on screen is the one that has just ended, the view
  advances to the new day, so leaving the app open overnight does not strand it on yesterday with no
  now-line and a total that has stopped moving. A day you navigated to is left where you put it:
  only today is carried across the boundary (§9.3).
- On first open the view scrolls to show the now-line, or the day's first entry for past days.
- Empty state: "No entries for this day", pointing at the composer — which is already on screen, so
  it needs no button of its own — plus **Add entry**.

### 8.3 Start composer

Not a sheet: a composer docked to the bottom of Today, always visible — a text field plus a filled
**Start** button. A modal was the first design. It cost a tap, hid the day behind it, made "start
something" a mode, and — worst — its keyboard-up-on-open covered the very suggestion list the
two-tap path depended on. A permanent input costs nothing when it is ignored.

- **At rest**: the field and the button, nothing else; the day keeps the screen. Nothing is focused
  on launch, because reviewing the day is the other half of the core loop (§2) and a soft keyboard
  covering the calendar on every launch is the wrong default. One tap on the field to type.
- **In use** (focused, or non-empty): the ranked **suggestions** (§9.6) expand *upward* over the
  calendar, filtered as you type, as a vertical list of rows (the activity's coloured dot, its
  name, "2 h ago"). The day behind dims under a scrim, which is not tappable — a tap-to-dismiss
  scrim is an unlabelled tap target (§10.4) and `Escape` already hands the screen back. One tap on a
  row starts it. Arrow keys move, Enter picks. It is drawn *over the calendar*, not above
  the field, so opening it costs calendar height and nothing else — stacking it on the field would
  grow the bottom bar and squeeze the running card and day header off the screen at large text
  scales (§10.2).
- Rank order runs top-down even though the panel opens upward, so `↓` always means "next best".
  Nearest-first was the alternative and was rejected for inverting that.
- An explicit consequence line when something is running: "Stops **Writing specs** at 14:32." It
  sits at the bottom of the panel, directly above the field, so the cause is next to the effect.
  This is the only warning; there is no confirmation dialog, because Undo covers it.
- **No note field.** A note is what distinguishes two spans of the same activity (§5.1), which is a
  judgement made after the fact and not at the instant you start. It is edited on the entry it
  belongs to (§8.4). Start takes a name and nothing else.
- No "Create **Deep work**" row either: pressing **Start** on a name that matches nothing creates
  it, so creation is still never a mode. The row was a modal-era affordance for a sheet that had no
  button of its own.
- Keyboard: Enter starts the highlighted row, or what is typed. `Escape` clears the field and hands
  focus back to the day. `Cmd/Ctrl+N` focuses the field. The composer swallows the day-view keys
  (`T`, `←`, `→`) while it has focus, so typing a "t" does not jump to today and the arrows move the
  caret instead of the day — and gives them straight back when it lets go.

### 8.4 Entry sheet (detail / edit)

Opened by tapping any block or history row. Contents, in order:

1. Activity name behind the activity's coloured spine — the same one its block carries, so the
   sheet is visibly about *that* block — and the note (inline-editable, ≤ 2000 chars).
   Tapping the name opens the **activity picker**: a name field over the §9.6 suggestions, which
   relabels this entry (§6.10), with "Rename or recolour…" demoted to a footer row for the
   all-history edit (§6.7). Like the note, the relabel commits on its own rather than through
   **Save**, so it is its own undo step (§7.5); the sheet closes behind it, because its header is
   about an activity that is no longer this entry's.
   The note commits when the field lets go rather than through **Save**, so one note change is one
   undo step (§7.5) and is never bundled with a time change. Enter inserts a line; a note is prose.
2. **Start**, **End**, **Duration** — one group with hairlines between the rows, not three loose
   rows, because they are three views of the same two instants: editing any two updates the
   third (editing duration moves `endAt`, or `startAt` for a boundary pinned by §7). Each has a
   time-picker affordance **and** `−`/`+` stepper buttons of one snap interval.
3. Conflict text inline when a typed value breaks a clamp (§7.2).
4. Actions, weighted: **Resume** (or **Continue**, §6.4) and **Split here…** as secondary buttons,
   **Delete** demoted and in the error colour, and **Save** as the one filled button, full width at
   the thumb end of the sheet.
5. For the running entry: **Stop** replaces the End field, which reads "running".

### 8.5 History

Reverse-chronological list grouped by day with sticky day headers and per-day totals; each row shows
colour, name, range, duration, and **Resume**. Search by activity name and note text. Filter by
activity. Lazy-loads by month. Swipe a row to delete (with undo); long-press for the context menu.

### 8.6 Settings

- Snap interval · 12/24-hour · first day of week · theme (system/light/dark) · default zoom.
- Continue window (§6.4) · long-run threshold.
- **Export a date range** (built): a CSV of the entries between two dates, for a spreadsheet or an
  invoice. Columns `id, activity, note, start_local, end_local, start_utc, end_utc,
  duration_minutes, tz`. Presets — this week, last week, this month, last month — plus a custom
  range, and a count and total shown before you commit. Shared via the platform share sheet / save
  dialog; downloaded on web.

  Three rules make the file trustworthy, and each has a test:
  - **Rows are clipped to the range.** An entry that began the evening before is reported starting
    at the range, so `duration_minutes` sums to *exactly* the time tracked in the range and agrees
    with the day totals of §5.3. One entry can therefore appear in two adjacent exports as two
    slices, sharing an `id`.
  - **A running entry is included with empty end columns**, its duration measured to the moment of
    export. Leaving it out would take hours off the total with nothing to explain the gap; filling
    in an end would record a moment that never happened.
  - **The file is written for machines**: `*_utc` in ISO 8601, `*_local` as `YYYY-MM-DD HH:MM`,
    RFC 4180 quoting, CRLF, and a UTF-8 BOM so Excel reads a non-ASCII activity name correctly.
    None of it follows the 12/24-hour display setting.

- **Export everything** (P4): JSON at full fidelity — `schemaVersion`, activities, entries,
  settings — which is the backup half of this and a different job from the extract above: it has to
  round-trip through import (§14.10), so it cannot be a slice.
- **Import** (built): JSON only. Merge by `id`, newest `updatedAt` wins; shows a dry-run summary
  (added / updated / skipped / rejected) before applying, and rejects any file that would break §4,
  naming the first offending pair. Two details worth stating because they are where this goes wrong:
  the §4 check runs over the **merged** timeline rather than over the incoming file alone — a file
  that is consistent with itself can still overlap what is already here — and the whole import is
  one transaction, so a rejected file changes nothing (§4.6). Tombstones are carried in the file and
  restored, or a round trip would resurrect everything ever deleted.
- **Delete all data**, with typed confirmation.
- About: version, licences, link to this spec.

---

## 9. Behaviour details

### 9.1 Persistence of the running state

A running entry is nothing but a stored `startUtc`. Elapsed time is always computed as
`now - startUtc` at read time; no timer accumulates state. Therefore app kill, OS kill, reboot,
device sleep, and clock-zone changes need **no** recovery code, and there is no background service,
no foreground service requirement, and no doze-mode problem. The UI timer is a pure display concern.

§6.11's day rollover is not an exception to this. It accumulates nothing and recovers nothing: it
only moves where one span is recorded as ending, so that a day owns its own entries. Elapsed time is
still `now - startUtc` over whatever the current entry is.

### 9.2 Clock jumps

If the wall clock moves backwards such that `now < runningEntry.startUtc`, the running card shows
"started in the future" with **Fix start time…** instead of a negative duration. Durations are
otherwise never rendered negative or as `--`.

### 9.3 Lifecycle

On resume: re-read the clock, re-render the now-line, re-run the long-run check, and run the §6.11
day rollover. It also runs at launch and on the 30-second tick, so a midnight that passes with the
app open is noticed within 30 seconds — and the instants it writes are the midnights themselves, so
being late changes nothing but the lag on the header.

That rollover is the only reconciliation pass in the app, and it exists because a midnight cannot be
written before it has passed (§4.5), not because any state needs recovering (§9.1). It is safe to
run at any time: it does nothing when nothing is running and nothing when no boundary has been
crossed.

The day the home screen shows follows the real day across that boundary, under the rule in §8.2:
the day that has just ended advances, a day you navigated to does not.

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
  is temporary. Export to keep your data." — shown on first launch. The signal is drift's chosen
  implementation being in-memory; anything that persists, even IndexedDB, is not warned about,
  because it is not a lie.
- Import of a file from a newer `schemaVersion`: refused with a clear message, never partially applied.

### 9.6 Suggestion ranking

For each non-archived activity, over the last 90 days:

```
score = Σ over its entries of 0.5 ^ (ageInDays / 7)      // 7-day half-life
```

so frequency and recency both count and neither dominates. While typing, rows whose `nameKey`
*starts with* the query are boosted above substring matches; ties break on most-recent use. One
activity is always excluded — whichever one picking would be a no-op: the running one in the start
composer (§8.3), the entry's current one in the activity picker (§8.4). With no history, the list is
empty and the field explains "Type what you are doing".

### 9.7 Colour

A 12-colour palette. Each slot is four colours — `fill`, `onFill`, `edge`, `tint` — built by solving
for a **target relative luminance** rather than by picking a lightness, because luminance is what
contrast is computed from. That makes the guarantees structural rather than something to re-check
whenever a hue is added: `fill`/`onFill` clears 4.5:1 and `fill`/`edge` clears 3:1 for *any* hue, in
both themes, and tests assert both for all twelve.

The hues are spread rather than evenly stepped — an even 30° walk spends four of the twelve slots on
reds and pinks, the hardest pairs to tell apart — and they are *ordered* so consecutive slots are far
apart, because new activities take the least-used slot and slots 0 and 1 are the two colours a new
user sees side by side. Slot 0 is a calm blue: on a running band a red reads as an alarm.
Neighbouring slots also alternate between two luminance tiers, so two activities created one after
the other stay distinct in grayscale and under a deuteranopia simulation, where the hue step gives
nothing.

**The arc 215°–277° is reserved.** The live accent (§9.8) sits in it, so no activity may. This is
what makes "a vivid indigo on screen means *now*" true rather than usually true, and it is asserted
in `palette_test.dart` alongside the ordering. It costs something worth naming: the blues stop at
214° and resume at 278°, so the palette carries one blue instead of three.

Colour is always accompanied by the name in text — it is never the only way to tell two blocks
apart (§10.3).

### 9.8 Design system and identity

The app is Material 3 with one set of decisions, held in `app/design.dart` (the scale and the two
voices), `app/theme.dart` (colour and every component theme) and `app/palette.dart` (activity
colour). A widget that needs a colour, a radius or a text style asks for one; it does not invent one.

**Identity.** Four rules, and the rest follows from them.

1. **Two voices.** Words are set in **Geist Sans**, every number in **Geist Mono** — the hour axis,
   the times on a block, durations, totals, the age beside a suggestion, the ticking readout. One
   designed superfamily, so the two voices are relatives. Both are vendored under `assets/fonts/`
   (SIL OFL): this app works offline and must look the same everywhere, and a font fetched at
   runtime does neither. `AppType.numeric` is how a call site says "this is a number".
2. **Colour means one of four things, and nothing else gets any.**

   | Colour | Means |
   | --- | --- |
   | One of the twelve activity hues (§9.7) | *this activity* — its block, spine, dot, running band |
   | The live accent | *now* — the now-line, the running state, the focus ring |
   | The error colour | *this is wrong* — a conflict, a clock jump, a database failure |
   | None | everything else: all chrome, all surfaces, all icons, all buttons |

3. **The accent is reserved** (§9.7). Its hue arc is struck from the activity palette, so it can
   never be mistaken for something a user named.
4. **Primary actions are ink** — near-black on light, near-white on dark. Start, Stop and Save are
   the loudest controls on the screen and deliberately colourless, which is what keeps the accent
   rare enough to mean anything. `theme_test.dart` asserts that `primary` carries no chroma.

**Minimal here means fewer things, not fewer affordances.** Nothing that is reachable becomes less
reachable to make the screen quieter; §10 is not negotiable against §9.8.

The mechanics:

- **Spacing** 4 / 8 / 12 / 16 / 24 / 32; **radii** 10 (blocks, fields) / 14 (grouped containers) /
  24 (sheets and the panel), with **buttons as pills** because a button is the one thing that should
  look pressable; **strokes** 1 hairline, 4 activity spine, 2 focus and now-line.
- **One surface, divided by hairlines.** The header, the day and the composer are the same tone;
  only things that sit *on* that surface (the running band, the total, a stepper's value, the
  suggestion panel) take a container tone. No elevation separates anything that is not floating.
- **One format for an amount of time, and a colon means a clock time.** A duration always carries
  its units — `0 min`, `45 min`, `1 h`, `1 h 05 min`, `12 h 30 min` — with the minutes padded after
  an hour so a column of them lines up in the mono, and dropped entirely on a whole hour. Two
  exceptions, both deliberate: the ticking readout is a stopwatch (`1:12:00`, §8.1) because it is a
  running counter rather than a measurement, and screen-reader text is spoken English
  (`1 hour 12 minutes`, §10.4) because it is read aloud. `test/core/formatters_test.dart` asserts the
  rule itself — that no duration string can contain a colon — not just its examples.
- **Icons**: the rounded set for strokes and arrows, the outline set for objects. Never both for the
  same glyph.
- **Roles the Material scheme has no word for** (live, axis rules, gutter spine, gap ink and hatch,
  scrim) are named in an `AppColors` theme extension, so nothing has to borrow `colorScheme.error`
  to mean "now".
- **Motion** is 90 ms for a state change on something already on screen and 120 ms for something
  arriving, through `Motion.of`, which returns zero when the platform asks for no animation (§10.2).
- **Thresholds that decide whether text fits are measured at the reader's text scale**, never
  written as pixel constants (§10.2).

**The mark** (`tool/brand/mark.svg`) is the same block: a span of the day with its live edge, on ink.
Not a clock — there is no clock face anywhere in this app. It is hand-written SVG, rasterised by
headless Chrome and fanned out to every platform by `flutter_launcher_icons`, so one file is the
source of all of them; `tool/brand/README.md` has the two commands.

### What adapts, and what does not

The app is a guest on six platforms. Its *manners* are the host's; its *identity* is its own.

| Invariant everywhere | Adapts per platform |
| --- | --- |
| The four colour meanings and the reserved accent (§9.7) | Corner radii, control height, density |
| Geist Sans / Geist Mono and the two-voice rule | Button shape: pill, capsule or cornered |
| The mark | Switches, segmented controls, dialogs, sheets, scrollbars |
| The calendar: axis, blocks, spine, gaps, now-line | Time and date pickers |
| Every §10 guarantee | Page transitions, back gesture, menu bar, window chrome |

`app/platform_style.dart` holds the numbers; `app/adaptive.dart` holds the controls that genuinely
differ. Where Flutter has an `.adaptive` constructor that is what is used. The split from
`design.dart` is deliberate: that file is the identity scale and does not vary.

**Apple: Liquid Glass.** Chrome is a translucent, blurred material that floats *over* the day rather
than sitting beside it — the header, the composer, the suggestion panel, the sheet and the zoom
control — with capsule controls and markedly rounder containers. Implemented in `app/glass.dart`,
which draws a tint, a backdrop blur and a single specular hairline on the lit edge, plus a soft
shadow so a floating surface reads as floating. Flutter cannot refract, so this is a likeness, not a
reproduction. **It degrades to opaque** under `MediaQuery.highContrast` — Flutter does not expose
Reduce Transparency, and that is the nearest honest signal — and text contrast is measured against
the opaque tint, so §10.3 holds in both states.

Because the header floats, the day owns the full height and takes a top inset from it. That inset is
measured rather than written down: it moves with the text scale, with the running activity's name
and with the safe area.

**Keyboard.** §10.5's "Cmd/Ctrl" is one shortcut with two names, not two shortcuts: the command key
is Cmd on Apple and Ctrl elsewhere, never both. On macOS the same callbacks are also a real menu bar
(app, Track, View), so a menu can never drift from its shortcut.

---

## 10. Accessibility requirements

Target **WCAG 2.2 AA**. These are acceptance criteria for every phase, not a late polish pass; a
feature that fails them is not done.

### 10.1 No gesture-only functionality

| Gesture | Equivalent |
| --- | --- |
| Long-press an edge, then drag, to resize (a plain vertical drag belongs to the scroll view) | Entry sheet Start/End/Duration fields + `−`/`+` steppers; `onIncrease`/`onDecrease` semantics actions on the block, whose `value` is the entry's duration; keyboard shortcuts (§10.5) |
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
- Day view is traversable in chronological order; the day header announces the date and the tracked
  total.
- Reading order and focus order match visual order; sheets trap focus and return it on dismiss.

### 10.5 Keyboard

Global: `Cmd/Ctrl+N` focus the start field · `Cmd/Ctrl+.` stop · `Cmd/Ctrl+R` resume last ·
`Cmd/Ctrl+F` search · `T` today · `←`/`→` previous/next day · `?` shortcut sheet. The bare-key
bindings (`T`, `←`, `→`) belong to the start field while it has focus, so it can be typed in; it
returns them when it lets go (§8.3).

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
| UI | Material 3, with a per-platform style layer and Cupertino controls where a design system genuinely differs (§9.8) | — |
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

**Unit — relabelling (§6.10).** `relabelKeepsTimesAndNote` ·
`relabelResolvesAnExistingActivityByNameKey` · `relabelCreatesTheActivityWhenTheNameIsNew` ·
`relabelIsUndoable` · `relabelToTheSameActivityChangesNothing` · `relabelWorksOnTheRunningEntry`.

**Unit — boundary math (§7).** `draggingSharedBoundaryConservesTotalTrackedTime` ·
`draggingFreeEdgeGrowsIntoGapOnly` · `clampStopsAtNeighbourMinusMinimum` ·
`snapRoundsInstantNotDelta` · `repeatedEditsDoNotDrift` · `runningEntryEndIsNotEditable` ·
`theBoundaryBeforeTheRunningEntryIsEditable` · `typedOverlapIsRejectedWithNamedConflict`.

**Unit — day/zone logic (§5.3).** `entryCrossingMidnightRendersInBothDays` ·
`dayTotalsClipToDayWindow` · `dstShortDayHas23HourAxis` · `dstLongDayHas25HourAxis` ·
`dayWindowFollowsRenderingZone`.

**Unit — day rollover (§6.11).** `runningEntryIsCutAtMidnight` ·
`rollOverRestartsTheSameActivityAndNote` · `rollOverBackfillsEveryMissedMidnight` ·
`rollOverKeepsTheSubMinuteScrapBeforeMidnight` · `rollOverConservesTotalTrackedTime` ·
`rollOverIsIdempotent` · `rollOverDoesNothingWhenNothingIsRunning` · `rollOverFollowsDstDayLength`.

**Unit — suggestions (§9.6).** `recentBeatsFrequentWithinHalfLife` · `prefixMatchOutranksSubstring` ·
`runningActivityIsExcluded`.

**Widget.** Running band states (idle / running / future-start) · calendar geometry (block position
and height for a given zoom, short-entry minimum, gap rendering) · start composer keyboard flow ·
entry-sheet three-field consistency · entry-sheet activity picker (pick, create, keyboard, and the
§6.7 route out of it) · the long-run banner measured across a midnight cut and staying dismissed
over one · the day view following midnight and leaving a navigated-to day alone ·
semantics labels and actions on blocks, gaps and steppers ·
golden tests at 1.0× and 2.0× text scale in light and dark.

The goldens are the only tests that protect the *look*: everything else asserts behaviour and would
stay green through a redesign. They render in the test font rather than Roboto, which is what keeps
them machine-independent — read them for layout, weight and colour, which is what drifts.

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
| **P3 Editing** | Drag handles, the §7 rules, entry sheet with typed fields and steppers, split, delete, change an entry's activity (§6.10), undo — each landing with its keyboard and screen-reader equivalent. | §7 tests green; a boundary can be corrected by drag, by typing, and by keyboard alone with identical results. |
| **P4 Daily usability** | History + search, export/import, settings, long-run banner, short-entry clustering, tap-a-gap-to-fill-it, empty/error states. | **Built.** Export → wipe → import round-trips, asserted in `backup_round_trip_test.dart`. §10.6's manual passes (TalkBack, VoiceOver, keyboard-only, 200 %) are still outstanding, as is the `integration_test` run, which needs a device. |
| **P4.1 Day rollover** | Stop and restart the running entry at midnight (§6.11), the catch-up pass at launch / resume / tick (§9.3) — the app's first lifecycle hook — the day view following midnight (§8.2), and the long-run threshold measured over the whole run (§8.1). | Rollover tests green; a clock left running overnight comes back as one entry per day with the 8 h banner still able to fire. |
| **P5 Platform affordances** | Android persistent notification with Stop/Resume actions, iOS Live Activity (best-effort), desktop global shortcuts + menubar/tray quick-start, web install/PWA polish. | Start and stop are reachable without opening the app on each platform that supports it. |
| **P6 Later** | Week view, per-activity reports, render-in-recorded-zone, projects/tags, optional sync. | Out of v1 scope; listed so the v1 model does not preclude them. |

Each phase ends with: `flutter analyze` clean, tests green, a11y criteria in §10 met for the new
surface, and the spec updated if the phase taught us something.

---

## 14. Acceptance criteria for v1

1. The start input is on screen at all times, so **nothing has to be opened** before starting —
   from a cold launch or from any other state. From there, starting is one tap on a suggestion row,
   or a typed name plus **Start**/Enter. Verified by test.
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
13. A clock left running across one or more midnights comes back as one entry per day plus a running
    one for today, with no time gained or lost, and the long-run banner still measuring the whole
    run. Verified by test.

---

## 15. Requirement traceability

The original request, mapped to where it is specified:

| Request | Specified in |
| --- | --- |
| Flutter app to track what I am doing | §1, §11.1 |
| Daily calendar view showing the logs | §8.1, §8.2, §5.3 |
| Really easy to use | §1 principles, §2, §8.1 and §8.3 (a start input always on screen), §9.4 |
| Accessible | §10 in full, §14.9 |
| Common UX patterns | §8 (M3, bottom nav/rail, sheets, FAB, SnackBar undo), §7.1 (calendar-standard boundaries) |
| Starting an action stops the current one | §4.1, §4.4, §6.1 |
| Log a start and a stop time | §5.1, §6.1, §6.2 |
| Resume an existing log as a new entry | §6.3, §6.4, §8.4, §8.5 |
| Change entry length afterwards to fix errors | §6.5, §7 in full, §8.4, §14.5 |
| Fix a mis-labelled entry afterwards | §6.10, §8.4 |
| Stop and restart entries at the end of the day | §6.11, §9.3, §8.2 |

---

## 16. Open questions

1. **Gap behaviour on delete** — v1 leaves a gap (invariant 7). If in real use deleting a mis-start
   usually means "give that time back to the neighbour", an opt-in "close the gap" action on delete
   is the smallest fix. Revisit after a week of P4 use.
2. **Continue window default** — 5 minutes is a guess. Instrument nothing; just see whether it feels
   right in P4 and change the default.
3. **Notes vs. activity names** — if notes end up carrying the real distinctions, that is the signal
   that tags (P6) are actually needed.
4. **Bundle identifier** — still needed before P5 (store-facing). The *name* is settled: **time-log**,
   carried by the manifest, the page title and the mark (§9.8). The Dart package stays `time_log`,
   because that is an identifier and not a name.
5. **Day total vs. the old footer** — the home screen now carries only the tracked total. If
   untracked time or the per-activity split turns out to be wanted at a glance, the day header is
   where it goes back; revisit in P4 alongside reports.
6. **Merging after a relabel** — §6.10 can leave two touching entries sharing an activity, and v1
   leaves both. If that turns out to be the common case rather than the exception, the smallest fix
   is a second SnackBar action offering to merge them, which needs a rule for which note survives.
   Revisit after real use.
7. **Finished entries that cross midnight** — §6.11 cuts only the running entry, so a span typed,
   dragged, gap-filled or imported across the date line is still one row (§5.3). That keeps the app
   from overruling a span someone entered deliberately, at the cost of two kinds of midnight-crossing
   entry existing. If the clipped rendering turns out to be the part nobody wants, the smallest fix is
   to cut on save as well — which also makes §5.3's clipping, and the code behind it, deletable.
