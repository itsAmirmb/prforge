import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../settings/presentation/settings_providers.dart';

/// Keeps the screen on while [child] (the workout screen) is open, if the
/// setting allows it.
class KeepScreenOn extends ConsumerStatefulWidget {
  const KeepScreenOn({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends ConsumerState<KeepScreenOn> {
  late final FeedbackService _service = ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    _service.keepScreenOn(ref.read(userSettingsProvider).keepScreenOn);
  }

  @override
  void dispose() {
    _service.keepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      userSettingsProvider.select((s) => s.keepScreenOn),
      (_, on) => _service.keepScreenOn(on),
    );
    return widget.child;
  }
}
