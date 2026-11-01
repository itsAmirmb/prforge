import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/app/theme.dart';

void main() {
  test('theme builds for both brightness modes', () {
    for (final b in Brightness.values) {
      final t = buildTheme(b);
      expect(t.brightness, b);
      expect(t.useMaterial3, isTrue);
    }
  });

  test('every text style has the readable on-surface color in both modes', () {
    for (final b in Brightness.values) {
      final t = buildTheme(b);
      final onSurface = t.colorScheme.onSurface;
      for (final style in [
        t.textTheme.titleMedium,
        t.textTheme.bodyLarge,
        t.textTheme.labelMedium,
        t.textTheme.headlineSmall,
      ]) {
        expect(style?.color, onSurface);
      }
    }
  });
}
