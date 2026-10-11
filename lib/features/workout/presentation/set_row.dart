import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../data/session_repository.dart';
import 'rest_timer_state.dart';
import 'workout_providers.dart';

/// One set: weight, reps, done toggle, delete. Every edit is saved at once.
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    super.key,
    required this.log,
    this.number,
    this.label,
    required this.onDelete,
  });

  final SetLog log;
  /// Set number, or [label] (exercise name) inside a superset round.
  final int? number;
  final String? label;
  final VoidCallback onDelete;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final _weight =
      TextEditingController(text: formatWeight(widget.log.weightKg));
  late final _reps = TextEditingController(text: widget.log.reps?.toString());
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  static double? _parseWeight(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void didUpdateWidget(SetRow old) {
    super.didUpdateWidget(old);
    // Show external changes, but never overwrite a field being typed in
    // (database echoes of earlier keystrokes would otherwise eat input).
    if (!_weightFocus.hasFocus &&
        _parseWeight(_weight.text) != widget.log.weightKg) {
      _weight.text = formatWeight(widget.log.weightKg) ?? '';
    }
    if (!_repsFocus.hasFocus &&
        int.tryParse(_reps.text.trim()) != widget.log.reps) {
      _reps.text = widget.log.reps?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  /// Marks the set done or not done; completing it starts the rest timer.
  Future<void> _toggle(SessionRepository repo) async {
    final completing = !widget.log.isCompleted;
    await repo.setCompleted(widget.log.id, completing);
    if (!completing) return;
    final rest = await repo.restAfterCompleting(widget.log.id);
    if (rest != null && mounted) {
      ref.read(restTimerProvider.notifier).start(rest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(sessionRepositoryProvider);
    final log = widget.log;
    final canToggle = log.isCompleted || log.reps != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: widget.label == null ? 28 : 76,
            child: Text(
              widget.label ?? '${widget.number}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: widget.label == null
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _weight,
              focusNode: _weightFocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                  labelText: 'kg', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => repo.setWeight(log.id, _parseWeight(v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _reps,
              focusNode: _repsFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'reps',
                  isDense: true,
                  border: OutlineInputBorder()),
              onChanged: (v) => repo.setReps(log.id, int.tryParse(v.trim())),
            ),
          ),
          IconButton(
            tooltip: log.isCompleted ? 'Mark not done' : 'Mark done',
            iconSize: 30,
            color: log.isCompleted ? Theme.of(context).colorScheme.primary : null,
            icon: Icon(log.isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked),
            onPressed: canToggle ? () => _toggle(repo) : null,
          ),
          IconButton(
            tooltip: 'Delete set',
            icon: const Icon(Icons.close),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
