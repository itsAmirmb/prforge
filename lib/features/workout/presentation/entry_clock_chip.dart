import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/entry_clock.dart';
import '../domain/session_blocks.dart';
import 'workout_providers.dart';

/// Ticks once a second, only while a clock is counting.
mixin _ClockTicker<T extends StatefulWidget> on State<T> {
  Timer? _ticker;

  void syncTicker(bool running) {
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
}

class _ClockView extends StatelessWidget {
  const _ClockView({required this.clock, required this.label});

  final EntryClock clock;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = clock.running ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      label: '$label ${formatStopwatch(clock.elapsed)}',
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

/// All sets of the session in one list, once the data is there and the
/// session is the active one; null otherwise (the clocks stay hidden).
({DateTime start, List<SetLog> sets})? _sessionSets(
    WidgetRef ref, int sessionId) {
  final session = ref.watch(activeSessionProvider).value;
  final entries = ref.watch(sessionEntriesProvider(sessionId)).value;
  if (session == null || session.id != sessionId || entries == null) {
    return null;
  }
  return (
    start: session.startedAt,
    sets: [
      for (final e in entries)
        for (final b in e.blocks) ...b.sets,
    ],
  );
}

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

class _EntryClockChipState extends ConsumerState<EntryClockChip>
    with _ClockTicker {
  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(userSettingsProvider.select((s) => s.showExerciseClock));
    final data = enabled ? _sessionSets(ref, widget.sessionId) : null;
    final currentId = ref.watch(currentSetIdProvider(widget.sessionId));

    final clock = data == null
        ? null
        : entryClock(
            entry: widget.entry,
            allSets: data.sets,
            sessionStart: data.start,
            isCurrent: currentId != null &&
                widget.entry.blocks
                    .any((b) => b.sets.any((s) => s.id == currentId)),
            now: DateTime.now(),
          );
    syncTicker(clock?.running ?? false);
    if (clock == null) return const SizedBox.shrink();
    return _ClockView(clock: clock, label: 'Exercise time');
  }
}

/// Timer of one set (see [setClock]); shown under the set's row.
class SetClockChip extends ConsumerStatefulWidget {
  const SetClockChip({super.key, required this.log});

  final SetLog log;

  @override
  ConsumerState<SetClockChip> createState() => _SetClockChipState();
}

class _SetClockChipState extends ConsumerState<SetClockChip>
    with _ClockTicker {
  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final enabled =
        ref.watch(userSettingsProvider.select((s) => s.showSetClock));
    final data = enabled ? _sessionSets(ref, log.sessionId) : null;
    final currentId = ref.watch(currentSetIdProvider(log.sessionId));

    final clock = data == null
        ? null
        : setClock(
            set: log,
            allSets: data.sets,
            sessionStart: data.start,
            isCurrent: currentId == log.id,
            now: DateTime.now(),
          );
    syncTicker(clock?.running ?? false);
    if (clock == null) return const SizedBox.shrink();
    return _ClockView(clock: clock, label: 'Set time');
  }
}
