import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/programs/domain/day_entries.dart';

void main() {
  // Items are (name, groupId).
  List<List<String>> entries(List<(String, int?)> items) =>
      toEntries(items, (i) => i.$2)
          .map((e) => e.map((i) => i.$1).toList())
          .toList();

  test('items without a group are single entries', () {
    expect(entries([('A', null), ('B', null)]), [
      ['A'],
      ['B']
    ]);
  });

  test('consecutive items of the same group form one entry', () {
    expect(entries([('A', null), ('B', 1), ('C', 1), ('D', null)]), [
      ['A'],
      ['B', 'C'],
      ['D']
    ]);
  });

  test('different groups stay separate even when adjacent', () {
    expect(entries([('A', 1), ('B', 1), ('C', 2), ('D', 2)]), [
      ['A', 'B'],
      ['C', 'D']
    ]);
  });

  test('empty list gives no entries', () {
    expect(entries([]), isEmpty);
  });
}
