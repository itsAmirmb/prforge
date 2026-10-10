/// Formats a weight without a trailing ".0" (7.5 -> "7.5", 5.0 -> "5").
/// Returns null for null so callers can decide the placeholder.
String? formatWeight(double? weight) {
  if (weight == null) return null;
  return weight == weight.roundToDouble()
      ? weight.toInt().toString()
      : weight.toString();
}
