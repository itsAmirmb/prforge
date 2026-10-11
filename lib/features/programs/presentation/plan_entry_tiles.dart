import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../data/prescription_repository.dart';
import '../domain/rep_scheme.dart';
import 'prescription_form_sheet.dart';
import 'prescription_providers.dart';
import 'superset_form_sheet.dart';

const _setTypeLabels = {
  SetKind.restPause: 'Rest-Pause',
  SetKind.drop: 'Drop set',
  SetKind.amrap: 'AMRAP',
};

String prescriptionSummary(ExercisePrescription p) {
  final scheme = parseRepScheme(p.repScheme);
  return [
    if (scheme != null)
      '${p.targetSets} sets: ${scheme.join(' · ')}'
    else if (p.targetReps != null)
      '${p.targetSets} × ${p.targetReps}'
    else
      '${p.targetSets} sets',
    if (p.targetWeightKg != null) '${formatWeight(p.targetWeightKg)} kg',
    if (p.restSeconds != null) 'rest ${p.restSeconds}s',
    if (_setTypeLabels[p.setType] != null) _setTypeLabels[p.setType]!,
  ].join(' · ');
}

Future<void> _confirmRemove(
    BuildContext context, WidgetRef ref, PrescriptionWithExercise item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove from plan?'),
      content: Text(
          '"${item.exercise.name}" will be removed from this day. Logged workouts are not affected.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(prescriptionRepositoryProvider).remove(item.prescription.id);
  }
}

/// A single (non-superset) exercise of the day.
class SinglePrescriptionTile extends ConsumerWidget {
  const SinglePrescriptionTile({
    super.key,
    required this.dayId,
    required this.item,
    required this.dragIndex,
    required this.nextSingle,
  });

  final int dayId;
  final PrescriptionWithExercise item;
  final int dragIndex;

  /// The next day entry if it is a single exercise (enables "Superset with next").
  final PrescriptionWithExercise? nextSingle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.exercise.name),
      subtitle: Text(prescriptionSummary(item.prescription)),
      onTap: () => showPrescriptionForm(context, dayId: dayId, existing: item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'superset') {
                ref.read(supersetRepositoryProvider).createGroup(
                    dayId, [item.prescription.id, nextSingle!.prescription.id]);
              } else {
                _confirmRemove(context, ref, item);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'superset',
                enabled: nextSingle != null,
                child: const Text('Superset with next'),
              ),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
          ReorderableDragStartListener(
            index: dragIndex,
            child: const Icon(Icons.drag_handle),
          ),
        ],
      ),
    );
  }
}

/// A superset: header with rounds/rest and its members in order.
class SupersetGroupCard extends ConsumerWidget {
  const SupersetGroupCard({
    super.key,
    required this.dayId,
    required this.group,
    required this.members,
    required this.dragIndex,
  });

  final int dayId;
  final SupersetGroup group;
  final List<PrescriptionWithExercise> members;
  final int dragIndex;

  String get _subtitle => [
        '${group.rounds} rounds',
        if (group.restBetweenSeconds != null)
          'rest between ${group.restBetweenSeconds}s',
        if (group.restAfterRoundSeconds != null)
          'rest after round ${group.restAfterRoundSeconds}s',
      ].join(' · ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supersetRepositoryProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          ListTile(
            title: Text(group.name ?? 'Superset'),
            subtitle: Text(_subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        showSupersetForm(context, group);
                      case 'add':
                        showPrescriptionForm(context,
                            dayId: dayId,
                            groupId: group.id,
                            lockedSets: group.rounds);
                      case 'ungroup':
                        repo.ungroup(group.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit superset')),
                    PopupMenuItem(value: 'add', child: Text('Add exercise')),
                    PopupMenuItem(value: 'ungroup', child: Text('Ungroup')),
                  ],
                ),
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
          ),
          for (var i = 0; i < members.length; i++)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 4),
              title: Text(members[i].exercise.name),
              subtitle: Text(prescriptionSummary(members[i].prescription)),
              onTap: () => showPrescriptionForm(context,
                  dayId: dayId, existing: members[i], lockedSets: group.rounds),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  final id = members[i].prescription.id;
                  switch (v) {
                    case 'up':
                      repo.moveMember(id, -1);
                    case 'down':
                      repo.moveMember(id, 1);
                    case 'leave':
                      repo.removeMember(id);
                    case 'remove':
                      _confirmRemove(context, ref, members[i]);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'up', enabled: i > 0, child: const Text('Move up')),
                  PopupMenuItem(
                      value: 'down',
                      enabled: i < members.length - 1,
                      child: const Text('Move down')),
                  const PopupMenuItem(
                      value: 'leave', child: Text('Remove from superset')),
                  const PopupMenuItem(
                      value: 'remove', child: Text('Remove from plan')),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
