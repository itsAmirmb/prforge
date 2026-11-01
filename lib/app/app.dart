import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/settings_providers.dart';
import 'app_shell.dart';
import 'theme.dart';

class PrforgeApp extends ConsumerWidget {
  const PrforgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(userSettingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'PRForge',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // On wide screens (tablets) the app is a centered column.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: child,
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}
