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
}
