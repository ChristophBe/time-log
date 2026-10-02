import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class TimeLogApp extends StatefulWidget {
  const TimeLogApp({super.key});

  @override
  State<TimeLogApp> createState() => _TimeLogAppState();
}

class _TimeLogAppState extends State<TimeLogApp> {
  final _router = buildRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'time-log',
    routerConfig: _router,
    theme: buildAppTheme(Brightness.light),
    darkTheme: buildAppTheme(Brightness.dark),
    debugShowCheckedModeBanner: false,
  );
}
