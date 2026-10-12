import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme.dart';

class PrforgeApp extends StatelessWidget {
  const PrforgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRForge',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AppShell(),
    );
  }
}
