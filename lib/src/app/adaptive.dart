import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design.dart';
import 'platform_style.dart';

/// Pickers in the idiom of the platform the app is a guest on (SPEC §9.8).
///
/// Apple platforms expect a wheel in a popup, Material a dial and a calendar
/// grid. Both return the same thing, so SPEC §7's clamping and the conflict
/// text do not know or care which one drew it — the one place an adaptive UI
/// is allowed to differ is how it looks and feels, never what it means.

/// A time, asked for in the platform's own way.
Future<TimeOfDay?> showAdaptiveTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  required String helpText,
  required bool use24h,
}) {
  if (!PlatformStyle.from(context).isApple) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
    );
  }

  // CupertinoDatePicker works in DateTimes where Material works in TimeOfDay,
  // so the wheel needs a date to hang the time on. Any date does: the caller
  // reads the hour and minute back and discards the rest. A constant one also
  // keeps the system clock out of the app, which is a rule with a grep behind
  // it (SPEC §11.4) — and that grep reads comments too.
  final seed = DateTime(2000, 1, 1, initial.hour, initial.minute);
  return _showWheel<TimeOfDay>(
    context,
    title: helpText,
    build: (onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      initialDateTime: seed,
      use24hFormat: use24h,
      onDateTimeChanged: (value) => onChanged(TimeOfDay.fromDateTime(value)),
    ),
    initial: initial,
  );
}

/// A date, asked for in the platform's own way.
Future<DateTime?> showAdaptiveDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Choose a date',
}) {
  if (!PlatformStyle.from(context).isApple) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: title,
    );
  }
  return _showWheel<DateTime>(
    context,
    title: title,
    build: (onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: initial,
      minimumDate: first,
      maximumDate: last,
      onDateTimeChanged: onChanged,
    ),
    initial: initial,
  );
}

/// The shell Apple puts a wheel in: a popup with Cancel and Done.
///
/// Nothing is committed until Done, which is the Apple convention and also what
/// keeps this the same shape as the Material pickers it stands in for — they
/// too return null when dismissed.
Future<T?> _showWheel<T>(
  BuildContext context, {
  required String title,
  required T initial,
  required Widget Function(ValueChanged<T>) build,
}) {
  var value = initial;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final media = MediaQuery.of(context);
      // Grows with the text scale and is capped at half the screen, so a wheel
      // at 200% neither clips its rows nor swallows the display (SPEC §10.2).
      final wheelHeight = math.min(
        media.size.height * 0.45,
        media.textScaler.scale(180),
      );
      return Container(
        color: scheme.surfaceContainerLow,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.xs,
                ),
                child: Row(
                  children: <Widget>[
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(value),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: wheelHeight,
                child: build((updated) => value = updated),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A dialog action in the platform's own idiom.
///
/// `AlertDialog.adaptive` switches the dialog itself, but not its buttons: a
/// `CupertinoAlertDialog` full of Material buttons is the worst of both. The
/// default action is the emphasised one on each side — filled on Material,
/// bold on Apple.
Widget adaptiveAction({
  required BuildContext context,
  required VoidCallback onPressed,
  required Widget child,
  bool isDefault = false,
}) {
  if (PlatformStyle.from(context).isApple) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: isDefault,
      child: child,
    );
  }
  return isDefault
      ? FilledButton(onPressed: onPressed, child: child)
      : TextButton(onPressed: onPressed, child: child);
}

/// A range of days, asked for in the platform's own way.
///
/// Material has a range picker; Apple has nothing of the kind, so there it is
/// two ordinary date wheels in sequence — which is also how Apple's own apps
/// ask for a range. Either way the answer is two inclusive local dates, and
/// the caller never learns which control produced them.
Future<({DateTime first, DateTime last})?> showAdaptiveDateRangePicker(
  BuildContext context, {
  required DateTime firstDay,
  required DateTime lastDay,
  required DateTime earliest,
  required DateTime latest,
}) async {
  if (!PlatformStyle.from(context).isApple) {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: firstDay, end: lastDay),
      firstDate: earliest,
      lastDate: latest,
    );
    if (picked == null) return null;
    return (first: picked.start, last: picked.end);
  }

  final from = await showAdaptiveDatePicker(
    context,
    initial: firstDay,
    first: earliest,
    last: latest,
    title: 'From',
  );
  if (from == null || !context.mounted) return null;

  final to = await showAdaptiveDatePicker(
    context,
    initial: lastDay.isBefore(from) ? from : lastDay,
    // Bounded below by the first date, so the second wheel cannot produce a
    // range that ends before it starts.
    first: from,
    last: latest,
    title: 'To',
  );
  if (to == null) return null;
  return (first: from, last: to);
}
