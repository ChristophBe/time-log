import 'package:flutter/material.dart';

/// Placeholder; P1 replaces this with the running card and start sheet.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, this.isoDate});

  final String? isoDate;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Today')),
    body: const Center(child: Text('Tracking arrives with P1.')),
  );
}
