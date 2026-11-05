import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../entry/activity_name_sheet.dart';

/// Asks what you were doing in a gap you just tapped (SPEC §8.2), or in a span
/// of unlogged active time (§9.9).
///
/// A name and nothing else, like the start composer: the times are already
/// decided — they are the gap's — and a note is a judgement made afterwards
/// on the entry itself (SPEC §8.3). The §9.6 suggestions sit under the field,
/// because naming something after the fact is where they help most.
Future<String?> showFillGapSheet(
  BuildContext context, {
  required DateTime startLocal,
  required DateTime endLocal,
  required Duration duration,
  required bool use24h,
  String title = 'Fill this gap',
}) => showActivityNameSheet(
  context,
  title: title,
  subtitle:
      '${formatTimeOfDay(startLocal, use24h: use24h)} – '
      '${formatTimeOfDay(endLocal, use24h: use24h)}  ·  '
      '${formatDuration(duration)}',
  commitLabel: 'Add entry',
);
