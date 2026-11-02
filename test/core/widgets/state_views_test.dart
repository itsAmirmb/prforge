import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/app/theme.dart';
import 'package:prforge/core/widgets/state_views.dart';

Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(theme: buildTheme(brightness), home: Scaffold(body: child));

void main() {
  testWidgets('EmptyState shows its message', (tester) async {
    await tester.pumpWidget(host(
        const EmptyState(icon: Icons.history, message: 'Nothing here yet.')));
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('ErrorState keeps the "Error: ..." text', (tester) async {
    await tester.pumpWidget(host(const ErrorState('boom')));
    expect(find.text('Error: boom'), findsOneWidget);
  });

  test('success color is a green that differs from the primary in both modes',
      () {
    for (final b in Brightness.values) {
      final scheme = buildTheme(b).colorScheme;
      expect(scheme.success, isNot(scheme.primary));
      expect(scheme.success.g, greaterThan(scheme.success.r));
    }
  });
}
