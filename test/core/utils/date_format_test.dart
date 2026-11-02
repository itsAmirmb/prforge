import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/utils/date_format.dart';

void main() {
  test('formatDate', () {
    expect(formatDate(DateTime(2026, 10, 11)), 'Sun, 11 Oct 2026');
    expect(formatDate(DateTime(2026, 1, 1)), 'Thu, 1 Jan 2026');
  });

  test('formatDateTime pads minutes', () {
    expect(formatDateTime(DateTime(2026, 10, 11, 9, 5)),
        'Sun, 11 Oct 2026 · 09:05');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 30)), '<1m');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(minutes: 72)), '1h 12m');
  });
}
