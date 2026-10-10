import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../data/prescription_repository.dart';
import 'prescription_providers.dart';

/// Set types selectable when planning (warm-up sets are logged, not planned).
const _plannedSetTypes = {
  SetKind.normal: 'Normal',
  SetKind.restPause: 'Rest-Pause',
  SetKind.drop: 'Drop set',
  SetKind.amrap: 'AMRAP',
};

/// Opens the add/edit sheet. Pass [existing] to edit.
Future<void> showPrescriptionForm(
  BuildContext context, {
  required int dayId,
  PrescriptionWithExercise? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PrescriptionFormSheet(dayId: dayId, existing: existing),
  );
}

class PrescriptionFormSheet extends ConsumerStatefulWidget {
  const PrescriptionFormSheet({super.key, required this.dayId, this.existing});

  final int dayId;
  final PrescriptionWithExercise? existing;

  @override
  ConsumerState<PrescriptionFormSheet> createState() =>
      _PrescriptionFormSheetState();
}

class _PrescriptionFormSheetState extends ConsumerState<PrescriptionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final ExercisePrescription? _p = widget.existing?.prescription;
  late final _sets = TextEditingController(text: '${_p?.targetSets ?? 3}');
  late final _reps = TextEditingController(text: _p?.targetReps?.toString());
  late final _weight =
      TextEditingController(text: _formatWeight(_p?.targetWeightKg));
  late final _rest = TextEditingController(text: _p?.restSeconds?.toString());
  late final _notes = TextEditingController(text: _p?.notes);
  late int? _exerciseId = _p?.exerciseId;
  late SetKind _setType = _plannedSetTypes.containsKey(_p?.setType)
      ? _p!.setType
      : SetKind.normal;

  static String? _formatWeight(double? w) {
    if (w == null) return null;
    return w == w.roundToDouble() ? w.toInt().toString() : w.toString();
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String? _optionalInt(String? v, {int min = 0}) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    return (n == null || n < min) ? 'Enter a whole number >= $min' : null;
  }

  static double? _parseWeight(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = PrescriptionDraft(
      exerciseId: _exerciseId!,
      targetSets: int.parse(_sets.text.trim()),
      targetReps: int.tryParse(_reps.text.trim()),
      targetWeightKg: _parseWeight(_weight.text),
      setType: _setType,
      restSeconds: int.tryParse(_rest.text.trim()),
      notes: _notes.text,
    );
    final repo = ref.read(prescriptionRepositoryProvider);
    final existing = _p;
    if (existing == null) {
      await repo.add(widget.dayId, draft);
    } else {
      await repo.update(existing.id, draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(exerciseListProvider(false)).value ?? const [];
    // An archived exercise already in the plan must stay selectable.
    final current = widget.existing?.exercise;
    final exercises = [
      ...active,
      if (current != null && !active.any((e) => e.id == current.id)) current,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (exercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Create an exercise first (Exercises tab).'),
                )
              else ...[
                DropdownButtonFormField<int>(
                  initialValue: _exerciseId,
                  decoration: const InputDecoration(labelText: 'Exercise'),
                  items: [
                    for (final e in exercises)
                      DropdownMenuItem(value: e.id, child: Text(e.name)),
                  ],
                  onChanged: (v) => setState(() => _exerciseId = v),
                  validator: (v) => v == null ? 'Choose an exercise' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sets,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sets'),
                        validator: (v) =>
                            _optionalInt(v, min: 1) ??
                            ((v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reps,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Reps'),
                        validator: (v) => _optionalInt(v, min: 1),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Target kg (optional)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final w = _parseWeight(v);
                          return (w == null || w < 0)
                              ? 'Enter a number >= 0'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rest,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Rest sec (optional)'),
                        validator: (v) => _optionalInt(v),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<SetKind>(
                  initialValue: _setType,
                  decoration: const InputDecoration(labelText: 'Set type'),
                  items: [
                    for (final e in _plannedSetTypes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _setType = v!),
                ),
                TextFormField(
                  controller: _notes,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child:
                      FilledButton(onPressed: _save, child: const Text('Save')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
