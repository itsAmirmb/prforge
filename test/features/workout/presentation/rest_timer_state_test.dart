import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/workout/presentation/rest_timer_bar.dart';
import 'package:prforge/features/workout/presentation/rest_timer_state.dart';

void main() {
  late ProviderContainer container;
  RestTimerState? timer() => container.read(restTimerProvider);
  RestTimerNotifier notifier() => container.read(restTimerProvider.notifier);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('idle until started', () => expect(timer(), isNull));

  test('start sets the end time and total', () {
    notifier().start(90);
    expect(timer()!.totalSeconds, 90);
    final remaining = timer()!.remaining().inSeconds;
    expect(remaining, inInclusiveRange(88, 90));
  });

  test('starting again restarts it; 0 does nothing', () {
    notifier().start(30);
    notifier().start(60);
    expect(timer()!.totalSeconds, 60);
    notifier().start(0);
    expect(timer()!.totalSeconds, 60);
  });

  test('adjust adds and removes time', () {
    notifier().start(60);
    notifier().adjust(15);
    expect(timer()!.totalSeconds, 75);
    expect(timer()!.remaining().inSeconds, inInclusiveRange(73, 75));
    notifier().adjust(-15);
    expect(timer()!.totalSeconds, 60);
  });

  test('removing all the time stops the timer', () {
    notifier().start(10);
    notifier().adjust(-15);
    expect(timer(), isNull);
  });

  test('adjust without a timer does nothing', () {
    notifier().adjust(15);
    expect(timer(), isNull);
  });

  test('stop clears it', () {
    notifier().start(10);
    notifier().stop();
    expect(timer(), isNull);
  });

  test('formatRest', () {
    expect(formatRest(const Duration(seconds: 90)), '1:30');
    expect(formatRest(const Duration(seconds: 5)), '0:05');
    expect(formatRest(const Duration(seconds: -3)), '0:00');
    expect(formatRest(const Duration(minutes: 12, seconds: 7)), '12:07');
  });
}
