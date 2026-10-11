import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/exercises/presentation/exercise_list_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/programs/presentation/program_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/workout/presentation/workout_providers.dart';
import '../features/workout/presentation/workout_session_screen.dart';

/// Bottom navigation between the top-level sections, plus a "Resume workout"
/// bar whenever a session is in progress.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider).value;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ProgramListScreen(),
          HistoryScreen(),
          ExerciseListScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active != null)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.fitness_center),
                title: const Text('Workout in progress'),
                trailing: const Text('Resume'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => WorkoutSessionScreen(sessionId: active.id),
                )),
              ),
            ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.list_alt), label: 'Programs'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(
                  icon: Icon(Icons.fitness_center), label: 'Exercises'),
              NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}
