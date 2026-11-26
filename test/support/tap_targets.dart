import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// SPEC §10.2: the smallest tappable node on a desktop, where the pointer is
/// precise and the compact styles draw controls 32-40 dp high.
const MinimumTapTargetGuideline desktopTapTargetGuideline =
    MinimumTapTargetGuideline(
      size: Size(32, 32),
      link: 'https://learn.microsoft.com/windows/apps/design/input/guidelines-for-targeting',
    );
