/// Splits [ordered] (sorted by plan order) into day entries: a lone item, or a
/// run of consecutive items sharing the same non-null group id (a superset).
///
/// Relies on the invariant kept by DayStructure.normalize: superset members
/// are stored consecutively.
List<List<T>> toEntries<T>(List<T> ordered, int? Function(T) groupOf) {
  final entries = <List<T>>[];
  int? currentGroup;
  for (final item in ordered) {
    final group = groupOf(item);
    if (group != null && group == currentGroup) {
      entries.last.add(item);
    } else {
      entries.add([item]);
      currentGroup = group;
    }
  }
  return entries;
}
