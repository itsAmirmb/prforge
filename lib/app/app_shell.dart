import 'package:flutter/material.dart';

import '../features/exercises/presentation/exercise_list_screen.dart';
import '../features/programs/presentation/program_list_screen.dart';

/// Bottom navigation between the top-level sections.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ProgramListScreen(), ExerciseListScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Programs'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Exercises'),
        ],
      ),
    );
  }
}
