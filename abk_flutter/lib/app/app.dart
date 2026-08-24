import 'package:flutter/material.dart';

import 'dev/dev_home_screen.dart';

/// App shell. The final product UI comes from Cloud Design in a later phase;
/// this hosts only the temporary engineering/dev screen used to exercise flows.
class AbkApp extends StatelessWidget {
  const AbkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABK (Foundation)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DevHomeScreen(),
    );
  }
}
