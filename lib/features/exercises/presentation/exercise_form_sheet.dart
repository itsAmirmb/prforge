import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'exercise_providers.dart';

/// Opens the add/edit sheet. Pass [exercise] to edit.
Future<void> showExerciseForm(BuildContext context, {Exercise? exercise}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ExerciseFormSheet(exercise: exercise),
  );
}

class ExerciseFormSheet extends ConsumerStatefulWidget {
  const ExerciseFormSheet({super.key, this.exercise});

  final Exercise? exercise;

  @override
  ConsumerState<ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends ConsumerState<ExerciseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.exercise?.name);
  late final _category = TextEditingController(text: widget.exercise?.category);
  late final _equipment =
      TextEditingController(text: widget.exercise?.equipment);
  late final _notes = TextEditingController(text: widget.exercise?.notes);
  late bool _isBodyweight = widget.exercise?.isBodyweight ?? false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _equipment.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(exerciseRepositoryProvider);
    final existing = widget.exercise;
    if (existing == null) {
      await repo.add(
        name: _name.text,
        category: _category.text,
        equipment: _equipment.text,
        notes: _notes.text,
        isBodyweight: _isBodyweight,
      );
    } else {
      await repo.update(
        existing.id,
        name: _name.text,
        category: _category.text,
        equipment: _equipment.text,
        notes: _notes.text,
        isBodyweight: _isBodyweight,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: widget.exercise == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              TextFormField(
                controller: _category,
                decoration:
                    const InputDecoration(labelText: 'Category (optional)'),
              ),
              TextFormField(
                controller: _equipment,
                decoration:
                    const InputDecoration(labelText: 'Equipment (optional)'),
              ),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bodyweight exercise'),
                value: _isBodyweight,
                onChanged: (v) => setState(() => _isBodyweight = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
