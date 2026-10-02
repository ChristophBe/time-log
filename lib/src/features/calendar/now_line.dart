import 'package:flutter/material.dart';

/// The "you are here" line (SPEC §8.2).
///
/// Static when animations are disabled; it never pulses, because a moving line
/// is decoration and the information is in its position and label.
class NowLine extends StatelessWidget {
  const NowLine({required this.label, required this.gutterWidth, super.key});

  final String label;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return IgnorePointer(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: gutterWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: color)),
        ],
      ),
    );
  }
}
