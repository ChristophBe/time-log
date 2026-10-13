import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/core/formatters.dart';

/// SPEC §9.8: a colon means a clock time; a duration carries its units.
void main() {
  Duration mins(int m) => Duration(minutes: m);

  group('formatDuration', () {
    const cases = <int, String>{
      0: '0 min',
      1: '1 min',
      59: '59 min',
      60: '1 h',
      61: '1 h 01 min',
      65: '1 h 05 min',
      120: '2 h',
      125: '2 h 05 min',
      750: '12 h 30 min',
      1440: '24 h',
    };

    cases.forEach((minutes, expected) {
      test('$minutes minutes reads "$expected"', () {
        expect(formatDuration(mins(minutes)), expected);
      });
    });

    test('seconds are dropped, never rounded up', () {
      // A 59-second entry has not lasted a minute, and saying it did would be
      // the one thing SPEC §4.3 is careful about.
      expect(formatDuration(const Duration(seconds: 59)), '0 min');
      expect(formatDuration(const Duration(seconds: 119)), '1 min');
    });

    test('a negative duration clamps rather than printing a minus', () {
      expect(formatDuration(mins(-30)), '0 min');
    });

    test('never contains a colon, at any length', () {
      // The rule itself, rather than ten instances of it: a colon on screen
      // always means a time of day.
      for (var minutes = 0; minutes <= 24 * 60; minutes++) {
        expect(
          formatDuration(mins(minutes)),
          isNot(contains(':')),
          reason: '$minutes minutes',
        );
      }
    });

    test('a whole hour never carries an empty minutes tail', () {
      for (var hours = 1; hours <= 24; hours++) {
        expect(formatDuration(mins(hours * 60)), '$hours h');
      }
    });
  });

  group('formatElapsed', () {
    test('is the one duration written with colons', () {
      // It is a running counter, not a measurement (SPEC §8.1).
      expect(formatElapsed(const Duration(seconds: 5)), '00:05');
      expect(formatElapsed(const Duration(minutes: 45)), '45:00');
      expect(formatElapsed(const Duration(hours: 1, minutes: 12)), '1:12:00');
      expect(formatElapsed(mins(-5)), '00:00');
    });
  });

  group('formatAge', () {
    const cases = <int, String>{
      0: '0 min',
      59: '59 min',
      60: '1 h',
      119: '1 h',
      120: '2 h',
      1439: '23 h',
      1440: '1 d',
      4320: '3 d',
    };

    cases.forEach((minutes, expected) {
      test('$minutes minutes ago reads "$expected"', () {
        expect(formatAge(mins(minutes)), expected);
      });
    });

    test('uses the same unit words as formatDuration', () {
      // Coarser, not different: whatever unit it lands on is spelled the way
      // every other duration spells it.
      for (final minutes in <int>[5, 59, 60, 180]) {
        final unit = formatAge(mins(minutes)).split(' ').last;
        expect(<String>['min', 'h'], contains(unit));
      }
    });
  });

  group('formatDurationVerbose', () {
    test('stays spoken English, because it is read aloud', () {
      // SPEC §10.4. The semantics assertions in accessibility_test.dart and the
      // announcements in action_feedback.dart depend on this exact wording.
      expect(formatDurationVerbose(mins(0)), '0 minutes');
      expect(formatDurationVerbose(mins(1)), '1 minute');
      expect(formatDurationVerbose(mins(60)), '1 hour');
      expect(formatDurationVerbose(mins(90)), '1 hour 30 minutes');
      expect(formatDurationVerbose(mins(120)), '2 hours');
    });
  });
}
