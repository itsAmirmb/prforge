import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback/headset_service.dart';
import '../features/exercises/presentation/exercise_list_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/programs/presentation/program_list_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/workout/presentation/workout_actions.dart';
import '../features/workout/presentation/workout_providers.dart';
import '../features/workout/presentation/workout_session_screen.dart';
import 'theme.dart';

/// Bottom navigation between the top-level sections, plus a "Resume workout"
/// bar whenever a session is in progress.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  StreamSubscription<void>? _headsetSub;

  @override
  void initState() {
    super.initState();
    // Headset button long-press: tick the current set of the active workout.
    _headsetSub = ref
        .read(headsetServiceProvider)
        .triggers
        .listen((_) => ref.read(workoutActionsProvider).completeCurrentSet());
  }

  @override
  void dispose() {
    _headsetSub?.cancel();
    super.dispose();
  }

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
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.medium),
            curve: AppMotion.curve,
            alignment: Alignment.bottomCenter,
            child: active == null
                ? const SizedBox(width: double.infinity)
                : _ResumeBar(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            WorkoutSessionScreen(sessionId: active.id),
                      ),
                    ),
                  ),
          ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Programs',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history_toggle_off),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Exercises',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Workout in progress" bar above the navigation bar; tap to resume.
class _ResumeBar extends StatelessWidget {
  const _ResumeBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: scheme.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Workout in progress',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                  Text(
                    'Resume',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
