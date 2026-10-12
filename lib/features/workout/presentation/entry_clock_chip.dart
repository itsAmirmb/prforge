import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../domain/entry_clock.dart';
import '../domain/session_blocks.dart';
import 'workout_providers.dart';

/// Small timer on an exercise card: counts while the exercise is being worked
/// on, then stays at the time it took. Hidden until the exercise is reached.
/// Everything is derived from the logged set times, so it survives restarts.
class EntryClockChip extends ConsumerStatefulWidget {
  const EntryClockChip({super.key, required this.sessionId, required this.entry});

  final int sessionId;
  final SessionEntry entry;

  @override
  ConsumerState<EntryClockChip> createState() => _EntryClockChipState();
}

class _EntryClockChipState extends ConsumerState<EntryClockChip> {
  Timer? _ticker;

  /// Ticks once a second, only while the clock is counting.
  void _syncTicker(bool running) {
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider).value;
    final entries = ref.watch(sessionEntriesProvider(widget.sessionId)).value;
    final currentId = ref.watch(currentSetIdProvider(widget.sessionId));

    EntryClock? clock;
    if (session != null && session.id == widget.sessionId && entries != null) {
      clock = entryClock(
        entry: widget.entry,
        allSets: [
          for (final e in entries)
            for (final b in e.blocks) ...b.sets,
        ],
        sessionStart: session.startedAt,
        isCurrent: currentId != null &&
            widget.entry.blocks
                .any((b) => b.sets.any((s) => s.id == currentId)),
        now: DateTime.now(),
      );
    }
    _syncTicker(clock?.running ?? false);
    if (clock == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final color = clock.running ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      label: 'Exercise time ${formatStopwatch(clock.elapsed)}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              formatStopwatch(clock.elapsed),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
