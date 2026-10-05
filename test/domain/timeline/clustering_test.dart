import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/clustering.dart';
import 'package:time_log/src/domain/timeline/day_timeline.dart';

/// SPEC §8.2: several entries too short to draw apart become one chip.
void main() {
  // The default zoom: 72 px/hour is 1.2 px per minute, and a block is never
  // drawn shorter than 18 px — which is 15 minutes' worth.
  const pixelsPerMinute = 1.2;
  const minHeight = 18.0;

  EntrySegment segment(String id, int startMinute, int lengthMinutes) {
    final start = DateTime.utc(2026, 3, 10).add(Duration(minutes: startMinute));
    final end = start.add(Duration(minutes: lengthMinutes));
    return EntrySegment(
      entry: TimeEntry(
        id: id,
        activityId: 'a1',
        startUtc: start,
        endUtc: end,
        tzName: 'Europe/Berlin',
      ),
      startUtc: start,
      endUtc: end,
      continuesBefore: false,
      continuesAfter: false,
      isRunning: false,
    );
  }

  List<SegmentCluster> cluster(List<EntrySegment> segments) => clusterSegments(
    segments,
    pixelsPerMinute: pixelsPerMinute,
    minHeight: minHeight,
  );

  test('entries with room between them are left alone', () {
    final clusters = cluster(<EntrySegment>[
      segment('a', 0, 60),
      segment('b', 60, 60),
    ]);
    expect(clusters, hasLength(2));
    expect(clusters.every((c) => !c.isCluster), isTrue);
  });

  test('entries closer together than one block height are grouped', () {
    // Three two-minute entries back to back: each would be drawn 18px tall
    // starting 2.4px below the last, so two of them are invisible.
    final clusters = cluster(<EntrySegment>[
      segment('a', 0, 2),
      segment('b', 2, 2),
      segment('c', 4, 2),
    ]);
    expect(clusters, hasLength(1));
    expect(clusters.single.segments, hasLength(3));
    expect(clusters.single.isCluster, isTrue);
  });

  test('a short entry with room after it is not a cluster', () {
    final clusters = cluster(<EntrySegment>[
      segment('short', 0, 2),
      segment('later', 60, 30),
    ]);
    expect(clusters, hasLength(2));
    expect(clusters.first.isCluster, isFalse);
  });

  test('zooming in pulls a cluster apart', () {
    final segments = <EntrySegment>[
      segment('a', 0, 2),
      segment('b', 2, 2),
      segment('c', 4, 2),
    ];
    // At the maximum zoom, 240 px/hour is 4 px per minute: two minutes is
    // 8 px... still under the minimum. Push further to prove the rule is about
    // the numbers rather than about the entries.
    final spread = clusterSegments(
      segments,
      pixelsPerMinute: 10,
      minHeight: minHeight,
    );
    expect(
      spread.every((c) => !c.isCluster),
      isTrue,
      reason: 'at 10px a minute, two minutes clears the 18px minimum',
    );
  });

  test('a cluster keeps its entries in order and keeps a stable id', () {
    final clusters = cluster(<EntrySegment>[
      segment('first', 0, 2),
      segment('second', 2, 2),
    ]);
    expect(clusters.single.segments.map((s) => s.entry.id), <String>[
      'first',
      'second',
    ]);
    expect(clusters.single.id, 'first');
  });

  test('an empty day has no clusters', () {
    expect(cluster(<EntrySegment>[]), isEmpty);
  });
}
