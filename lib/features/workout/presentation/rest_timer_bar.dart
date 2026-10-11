import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rest_timer_state.dart';

String formatRest(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Bottom bar of the workout screen: counts down the rest after a set, with
/// -15s / +15s / skip. Vibrates and beeps when the rest is over.
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick only while a timer is running.
    ref.listenManual<RestTimerState?>(restTimerProvider, (_, next) {
      _ticker?.cancel();
      _ticker = next == null
          ? null
          : Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    }, fireImmediately: true);
  }

  void _tick() {
    final timer = ref.read(restTimerProvider);
    if (timer == null) return;
    if (timer.remaining() <= Duration.zero) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      ref.read(restTimerProvider.notifier).stop();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(restTimerProvider);
    if (timer == null) return const SizedBox.shrink();

    final notifier = ref.read(restTimerProvider.notifier);
    final remaining = timer.remaining();
    final progress =
        (remaining.inMilliseconds / (timer.totalSeconds * 1000)).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text('Rest ${formatRest(remaining + const Duration(milliseconds: 999))}',
                  style: theme.textTheme.titleMedium),
              const SizedBox(width: 12),
              Expanded(child: LinearProgressIndicator(value: progress)),
              TextButton(
                  onPressed: () => notifier.adjust(-15),
                  child: const Text('−15s')),
              TextButton(
                  onPressed: () => notifier.adjust(15),
                  child: const Text('+15s')),
              IconButton(
                tooltip: 'Skip rest',
                icon: const Icon(Icons.close),
                onPressed: notifier.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
