import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../exercises/presentation/exercise_providers.dart';

/// Lets the user pick one of the (non-archived) exercises; null if dismissed.
Future<Exercise?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ExercisePicker(),
  );
}

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exerciseListProvider(false));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search exercises',
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Flexible(
                child: async.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Padding(padding: const EdgeInsets.all(24), child: Text('Error: $e')),
                  data: (all) {
                    final list = [
                      for (final e in all)
                        if (e.name.toLowerCase().contains(_query)) e,
                    ];
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No exercises found. Create one in the Exercises tab.'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(list[i].name),
                        subtitle: list[i].category == null
                            ? null
                            : Text(list[i].category!),
                        onTap: () => Navigator.of(context).pop(list[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
