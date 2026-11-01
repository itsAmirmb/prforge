/// One planned set produced by progressive loading.
class PlannedSet {
  const PlannedSet({required this.weight, required this.isNewWeight});

  final double weight;
  final bool isNewWeight;

  @override
  bool operator ==(Object other) =>
      other is PlannedSet &&
      other.weight == weight &&
      other.isNewWeight == isNewWeight;

  @override
  int get hashCode => Object.hash(weight, isNewWeight);

  @override
  String toString() => 'PlannedSet($weight, new: $isNewWeight)';
}

/// Splits [totalSets] between [newWeight] and [previousWeight].
///
/// Pure function: it only decides the per-set weights. The caller creates one
/// independent SetLog per result; reps stay user-editable per set.
/// New-weight sets come first, e.g. 3 sets, 2 new -> [7.5, 7.5, 5].
List<PlannedSet> planProgressiveLoading({
  required int totalSets,
  required double previousWeight,
  required double newWeight,
  required int setsAtNewWeight,
}) {
  if (totalSets < 1) {
    throw ArgumentError.value(totalSets, 'totalSets', 'must be >= 1');
  }
  if (setsAtNewWeight < 0 || setsAtNewWeight > totalSets) {
    throw ArgumentError.value(
        setsAtNewWeight, 'setsAtNewWeight', 'must be within 0..$totalSets');
  }
  return [
    for (var i = 0; i < totalSets; i++)
      i < setsAtNewWeight
          ? PlannedSet(weight: newWeight, isNewWeight: true)
          : PlannedSet(weight: previousWeight, isNewWeight: false),
  ];
}
