import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../settings/presentation/settings_providers.dart';
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

  @override
  void initState() {
    super.initState();
    // Resuming a workout: bring the current set into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(currentSetIdProvider(widget.log.sessionId)) ==
              widget.log.id) {
        _revealIfNeeded();
      }
    });
  }

  /// Scrolls the list so this row sits comfortably in view, unless it
  /// already does.
  void _revealIfNeeded() {
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    final box = context.findRenderObject();
    if (scrollable == null || box == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = scrollable.position;
    final target = viewport
        .getOffsetToReveal(box, 0.4)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < position.viewportDimension * 0.3) {
      return;
    }
    position.animateTo(target,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _selectAll(TextEditingController c) =>
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);

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
    final settings = ref.read(userSettingsProvider);
    ref.read(feedbackServiceProvider).setDone(vibration: settings.vibration);
    final rest = await repo.restAfterCompleting(widget.log.id,
        defaultRest: settings.restSeconds);
    if (rest != null && mounted) {
      ref.read(restTimerProvider.notifier).start(rest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(sessionRepositoryProvider);
    final log = widget.log;
    final canToggle = log.isCompleted || log.reps != null;
    final scheme = Theme.of(context).colorScheme;

    final isCurrent = ref.watch(currentSetIdProvider(log.sessionId)) == log.id;
    // When this set becomes the one to do next, scroll to it.
    ref.listen<int?>(currentSetIdProvider(log.sessionId), (_, next) {
      if (next == log.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealIfNeeded());
      }
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
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
              textInputAction: TextInputAction.next,
              onTap: () => _selectAll(_weight),
              decoration: const InputDecoration(labelText: 'kg'),
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
              textInputAction: TextInputAction.done,
              onTap: () => _selectAll(_reps),
              decoration: const InputDecoration(labelText: 'reps'),
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
