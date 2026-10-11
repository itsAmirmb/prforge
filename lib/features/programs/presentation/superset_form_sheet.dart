import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'prescription_providers.dart';

Future<void> showSupersetForm(BuildContext context, SupersetGroup group) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SupersetFormSheet(group: group),
  );
}

/// Edits name, rounds and rest of a superset. Rounds = sets of every member.
class SupersetFormSheet extends ConsumerStatefulWidget {
  const SupersetFormSheet({super.key, required this.group});

  final SupersetGroup group;

  @override
  ConsumerState<SupersetFormSheet> createState() => _SupersetFormSheetState();
}

class _SupersetFormSheetState extends ConsumerState<SupersetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group.name);
  late final _rounds = TextEditingController(text: '${widget.group.rounds}');
  late final _between =
      TextEditingController(text: widget.group.restBetweenSeconds?.toString());
  late final _afterRound = TextEditingController(
      text: widget.group.restAfterRoundSeconds?.toString());

  @override
  void dispose() {
    _name.dispose();
    _rounds.dispose();
    _between.dispose();
    _afterRound.dispose();
    super.dispose();
  }

  static String? _int(String? v, {required int min, bool required = false}) {
    if (v == null || v.trim().isEmpty) return required ? 'Required' : null;
    final n = int.tryParse(v.trim());
    return (n == null || n < min) ? 'Enter a whole number >= $min' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(supersetRepositoryProvider).updateGroup(
          widget.group.id,
          name: _name.text,
          rounds: int.parse(_rounds.text.trim()),
          restBetweenSeconds: int.tryParse(_between.text.trim()),
          restAfterRoundSeconds: int.tryParse(_afterRound.text.trim()),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name (optional)'),
              ),
              TextFormField(
                controller: _rounds,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Rounds (sets of every exercise)'),
                validator: (v) => _int(v, min: 1, required: true),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _between,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Rest between exercises (sec)'),
                      validator: (v) => _int(v, min: 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _afterRound,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Rest after round (sec)'),
                      validator: (v) => _int(v, min: 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child:
                    FilledButton(onPressed: _save, child: const Text('Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
