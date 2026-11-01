import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Keeps a day's plan structurally consistent after any change:
///  - groups with fewer than 2 members are dissolved,
///  - members pointing to a missing group become single exercises,
///  - superset members are stored consecutively (a group sits where its first
///    member was) with supersetOrder 0..n-1,
///  - orderIndex of prescriptions and groups is renumbered without gaps.
///
/// Call it inside the same transaction as the change.
class DayStructure {
  DayStructure(this._db);

  final AppDatabase _db;

  Future<List<ExercisePrescription>> _prescriptions(int dayId) {
    return (_db.select(_db.exercisePrescriptions)
          ..where((p) => p.workoutDayId.equals(dayId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.orderIndex),
            (p) => OrderingTerm.asc(p.id),
          ]))
        .get();
  }

  Future<void> normalize(int dayId) async {
    var prescriptions = await _prescriptions(dayId);
    var groups = await (_db.select(_db.supersetGroups)
          ..where((g) => g.workoutDayId.equals(dayId)))
        .get();

    // 1. Dissolve small groups and unlink orphans.
    final memberCount = <int, int>{};
    for (final p in prescriptions) {
      final gid = p.supersetGroupId;
      if (gid != null) memberCount[gid] = (memberCount[gid] ?? 0) + 1;
    }
    final validGroups = {
      for (final g in groups)
        if ((memberCount[g.id] ?? 0) >= 2) g.id,
    };
    for (final p in prescriptions) {
      final gid = p.supersetGroupId;
      if (gid != null && !validGroups.contains(gid)) {
        await (_db.update(_db.exercisePrescriptions)
              ..where((x) => x.id.equals(p.id)))
            .write(const ExercisePrescriptionsCompanion(
          supersetGroupId: Value(null),
          supersetOrder: Value(null),
        ));
      }
    }
    for (final g in groups) {
      if (!validGroups.contains(g.id)) {
        await (_db.delete(_db.supersetGroups)..where((x) => x.id.equals(g.id)))
            .go();
      }
    }

    // 2. Renumber: groups sit at their first member's position.
    prescriptions = await _prescriptions(dayId);
    groups = await (_db.select(_db.supersetGroups)
          ..where((g) => g.workoutDayId.equals(dayId)))
        .get();
    final seen = <int>{};
    var index = 0;
    var entry = 0;
    for (final p in prescriptions) {
      final gid = p.supersetGroupId;
      if (gid == null) {
        await (_db.update(_db.exercisePrescriptions)
              ..where((x) => x.id.equals(p.id)))
            .write(ExercisePrescriptionsCompanion(orderIndex: Value(index++)));
        entry++;
      } else if (seen.add(gid)) {
        final members = prescriptions
            .where((x) => x.supersetGroupId == gid)
            .toList()
          ..sort((a, b) {
            final byOrder = (a.supersetOrder ?? 1 << 30)
                .compareTo(b.supersetOrder ?? 1 << 30);
            return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
          });
        for (var j = 0; j < members.length; j++) {
          await (_db.update(_db.exercisePrescriptions)
                ..where((x) => x.id.equals(members[j].id)))
              .write(ExercisePrescriptionsCompanion(
            orderIndex: Value(index++),
            supersetOrder: Value(j),
          ));
        }
        await (_db.update(_db.supersetGroups)..where((x) => x.id.equals(gid)))
            .write(SupersetGroupsCompanion(orderIndex: Value(entry++)));
      }
    }
  }
}
