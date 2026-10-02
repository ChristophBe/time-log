# time-log

A Flutter app for logging what you are doing during the day. One activity runs at a time; starting a
new one stops the current one. The day is shown as a calendar you can read at a glance, resume past
work from, and correct afterwards.

**[`SPEC.md`](SPEC.md) is the contract.** It describes the whole app, including the parts not built
yet, and every non-obvious decision is written down there with its reasoning. Read it before
changing behaviour — in particular §4 (the timeline invariants), §7 (boundary editing) and §10
(accessibility), which are the parts that are expensive to get wrong.

## Status

Phases **P0–P3** of `SPEC.md` §13 are built: tracking, the day calendar, and editing.

| Works today | Not built yet (SPEC §13, P4–P6) |
| --- | --- |
| Start / stop / resume / continue, with undo on everything | History screen and search |
| Day calendar: hour axis, now-line, gaps, midnight splitting, DST-correct days | Export / import |
| Correcting a boundary by drag, by typing, or by keyboard alone | "Still tracking after 8 h?" banner |
| Ranked activity suggestions, 12-colour palette | Tapping a gap to fill it |
| Minimal settings: snap interval, 12/24 h, theme | Notifications, desktop tray, week view, reports |

## Running it

```sh
flutter pub get
dart run build_runner build      # drift + riverpod code generation
flutter run -d chrome            # or: -d macos, -d android, …
```

Code generation is required after changing anything under `lib/src/data/db/` or any `@riverpod`
provider. `dart run build_runner watch` during development.

### Platform notes

The app targets Android, iOS, macOS, Windows, Linux and web from one codebase. Only **web** has been
built and run so far, because this machine has no Android SDK and no Xcode — the other platform
folders are scaffolded and should build once those toolchains are installed, but that is unverified.

Correctness does not depend on a device: all 175 tests run on the Dart VM.

On the web, drift picks the best storage the browser offers. `flutter run`'s dev server does not send
the COOP/COEP headers that OPFS needs, so it generally falls back to IndexedDB — both persist, so
this only affects performance. In a private window there may be no persistent storage at all; the
app says so rather than pretending the data is safe.

## Tests

```sh
flutter analyze
dart format --set-exit-if-changed .
flutter test
```

The suite is organised by what it protects, not by file:

- `test/domain/timeline_writer_test.dart` — every invariant in SPEC §4 and action in §6, against a
  real in-memory SQLite database with a clock the test drives.
- `test/domain/editing_paths_test.dart` — the acceptance criterion from SPEC §14.5: a correction made
  by drag, by typing and by keyboard must produce the same timeline.
- `test/domain/timeline/` — pure boundary arithmetic, snapping, day windows, gaps, conflicts.
- `test/features/accessibility_test.dart` — SPEC §10 as assertions: tap-target and contrast
  guidelines, labelled controls, 200 % text scale, keyboard-only operation, and the rule that the
  ticking elapsed readout stays *out* of the semantics tree.
- `test/architecture_test.dart` — no `DateTime.now()` outside `core/clock.dart`; `domain/timeline`
  and `domain/models` import neither Flutter nor Drift.

Widget tests run against fixed provider state and a mock writer, not a real database: drift's queries
complete on the real event loop and deadlock inside `testWidgets`' fake-async zone. The database
behaviour is covered against real SQLite by the writer tests instead.

## How it is put together

```
lib/src/
  core/        clock, formatters, ids, time zone, colour contrast
  data/db/     schema.drift (= SPEC §5.2 verbatim), generated database, mappers
  data/repositories/   read-side stream queries
  domain/models/       Activity, TimeEntry, AppSettings — pure Dart
  domain/timeline/     boundary math, day windows, gaps, totals, conflicts — pure Dart
  domain/timeline_writer.dart   the only code that writes to the timeline
  features/    today, calendar, entry, settings
```

Three load-bearing ideas:

1. **One writer.** `TimelineWriter` is the only code that mutates entries. Each method is a single
   transaction that reads the affected neighbourhood, computes with the pure functions in
   `domain/timeline/`, re-checks SPEC §4, writes, and returns an undo token. A failed check rolls the
   whole thing back, so the timeline is never half-changed.

2. **The invariants are in the schema where they can be.** At most one running entry is enforced by a
   `UNIQUE` index over a generated column — SQLite treats NULLs in a unique index as distinct, so
   exactly one row can hold the value `1`. Non-overlap has no SQL equivalent and is enforced in the
   writer's transaction.

3. **No background execution.** A running entry is just a stored `startUtc`; elapsed time is
   `now - startUtc`, computed on read. App kill, reboot and device sleep therefore need no recovery
   code, and there is no foreground-service or doze-mode problem on any platform.
