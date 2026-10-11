import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../domain/progression_summary.dart';
import '../domain/session_blocks.dart';
import 'workout_providers.dart';

/// Bottom sheet that records the user's decision: new weight + how many of the
/// remaining sets use it. Applies it to the block's unfinished sets.
Future<void> showProgressiveLoadingSheet(
  BuildContext context, {
  required int sessionId,
  required ExerciseBlock block,
  required List<SetLog> last,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProgressiveLoadingSheet(
        sessionId: sessionId, block: block, last: last),
  );
}

class ProgressiveLoadingSheet extends ConsumerStatefulWidget {
  const ProgressiveLoadingSheet({
    super.key,
    required this.sessionId,
    required this.block,
    required this.last,
  });

  final int sessionId;
  final ExerciseBlock block;
  final List<SetLog> last;

  @override
  ConsumerState<ProgressiveLoadingSheet> createState() =>
      _ProgressiveLoadingSheetState();
}

class _ProgressiveLoadingSheetState
    extends ConsumerState<ProgressiveLoadingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<SetLog> _editable =
      widget.block.sets.where((s) => !s.isCompleted).toList();
  late final _previous = TextEditingController(
      text: formatWeight(
          _editable.map((s) => s.weightKg).whereType<double>().lastOrNull));
  final _new = TextEditingController();
  late final _reps =
      TextEditingController(text: _editable.firstOrNull?.reps?.toString());
  int _atNew = 1;

  int get _total => _editable.length;

  static double? _w(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _previous.dispose();
    _new.dispose();
    _reps.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(sessionRepositoryProvider).applyProgressiveLoading(
          sessionId: widget.sessionId,
          exerciseId: widget.block.exercise.id,
          prescriptionId: widget.block.prescriptionId,
          previousWeight: _w(_previous.text)!,
          newWeight: _w(_new.text)!,
          setsAtNewWeight: _atNew,
          reps: int.tryParse(_reps.text.trim()),
        );
    if (mounted) Navigator.of(context).pop();
  }

  String? _weightValidator(String? v) {
    final w = _w(v ?? '');
    return (w == null || w < 0) ? 'Enter a number >= 0' : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prevW = _w(_previous.text);
    final newW = _w(_new.text);
    final usage = newW == null ? null : lastTimeUsage(widget.last, newW);
    final remaining = _total - _atNew;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Progressive loading · ${widget.block.exercise.name}',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _previous,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Previous kg'),
                      validator: _weightValidator,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _new,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(labelText: 'New kg'),
                      validator: (v) {
                        final base = _weightValidator(v);
                        if (base != null) return base;
                        return _w(v!) == _w(_previous.text)
                            ? 'Must differ from previous'
                            : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (usage != null && usage.atWeight > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Last time: ${usage.atWeight} of ${usage.total} sets at ${formatWeight(newW)} kg',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),
              Text('Sets at new weight (of $_total unfinished)',
                  style: theme.textTheme.labelLarge),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Fewer',
                    icon: const Icon(Icons.remove),
                    onPressed:
                        _atNew > 0 ? () => setState(() => _atNew--) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_atNew / $_total',
                        style: theme.textTheme.headlineSmall),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'More',
                    icon: const Icon(Icons.add),
                    onPressed:
                        _atNew < _total ? () => setState(() => _atNew++) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('Remaining: $remaining at previous weight',
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
              if (newW != null && prevW != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [
                      if (_atNew > 0) '${formatWeight(newW)} kg × $_atNew',
                      if (remaining > 0) '${formatWeight(prevW)} kg × $remaining',
                    ].join('  +  '),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reps,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Target reps for these sets'),
              ),
              if (widget.block.sets.any((s) => s.isCompleted))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Completed sets are not changed.',
                      style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _apply, child: const Text('Apply')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
