/// Reps per set, e.g. "12,10,8,8" (stored as text in the plan).

/// Parses the stored text; null for empty or invalid input.
List<int>? parseRepScheme(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final values = <int>[];
  for (final part in text.split(',')) {
    final n = int.tryParse(part.trim());
    if (n == null || n < 1) return null;
    values.add(n);
  }
  return values;
}

/// Text for storage; null when there is no scheme.
String? formatRepScheme(List<int>? scheme) =>
    (scheme == null || scheme.isEmpty) ? null : scheme.join(',');

bool isValidRepScheme(List<int> scheme) =>
    scheme.isNotEmpty && scheme.every((r) => r >= 1);

/// Parses what the user typed. Accepts "10", "12, 10, 8, 8" and also Persian
/// digits and the Persian/Arabic comma. Null for empty or invalid input.
List<int>? parseRepsInput(String text) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final p = persian.indexOf(ch);
    final a = arabic.indexOf(ch);
    if (p >= 0) {
      buffer.write(p);
    } else if (a >= 0) {
      buffer.write(a);
    } else if (ch == '،' || ch == '٫') {
      buffer.write(',');
    } else {
      buffer.write(ch);
    }
  }
  return parseRepScheme(buffer.toString());
}

/// Reps for the set at [index] (0-based): the scheme value, the last scheme
/// value when the plan has more sets than the scheme, else [fallback].
int? repsForSet(int index, {List<int>? scheme, int? fallback}) {
  if (scheme == null || scheme.isEmpty) return fallback;
  return index < scheme.length ? scheme[index] : scheme.last;
}
