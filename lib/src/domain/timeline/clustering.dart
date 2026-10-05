import 'day_timeline.dart';

/// A run of entries too short to draw side by side at the current zoom.
class SegmentCluster {
  const SegmentCluster(this.segments);

  final List<EntrySegment> segments;

  bool get isCluster => segments.length > 1;

  EntrySegment get first => segments.first;

  /// Stable across rebuilds, so an expanded cluster stays expanded.
  String get id => segments.first.entry.id;
}

/// Groups segments that would overlap each other on screen (SPEC §8.2).
///
/// A block is never drawn shorter than [minHeight], so several entries inside
/// one [minHeight]'s worth of time do not get shorter — they get *stacked on
/// top of each other*, and the ones underneath become unreachable. Grouping
/// them into one chip is what keeps them reachable.
///
/// Pure, and taking the two numbers it needs rather than the metrics object, so
/// the rule can be tested without a calendar.
List<SegmentCluster> clusterSegments(
  List<EntrySegment> segments, {
  required double pixelsPerMinute,
  required double minHeight,
}) {
  final clusters = <SegmentCluster>[];
  var current = <EntrySegment>[];

  for (final segment in segments) {
    if (current.isEmpty) {
      current.add(segment);
      continue;
    }
    // The previous block is drawn at least minHeight tall starting at its own
    // offset; this one collides if it begins before that bottom edge.
    final previous = current.last;
    final gapMinutes = segment.startUtc.difference(previous.startUtc).inMinutes;
    final previousDrawn = _drawnHeight(previous, pixelsPerMinute, minHeight);
    if (gapMinutes * pixelsPerMinute < previousDrawn) {
      current.add(segment);
    } else {
      clusters.add(SegmentCluster(List<EntrySegment>.unmodifiable(current)));
      current = <EntrySegment>[segment];
    }
  }
  if (current.isNotEmpty) {
    clusters.add(SegmentCluster(List<EntrySegment>.unmodifiable(current)));
  }
  return clusters;
}

double _drawnHeight(
  EntrySegment segment,
  double pixelsPerMinute,
  double minHeight,
) {
  final minutes = segment.endUtc.difference(segment.startUtc).inMinutes;
  final exact = minutes * pixelsPerMinute;
  return exact < minHeight ? minHeight : exact;
}
