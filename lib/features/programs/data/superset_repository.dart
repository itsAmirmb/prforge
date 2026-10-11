import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/day_entries.dart';
import '../domain/rep_scheme.dart';
import 'day_structure.dart';
import 'prescription_repository.dart';

/// Superset groups of a workout day. Members are ordinary prescriptions that
/// point to the group; `rounds` is the number of sets of every member.
class SupersetRepository {
  SupersetRepository(this._db) : _structure = DayStructure(_db);

  final AppDatabase _db;
  final DayStructure _structure;

  Stream<List<SupersetGroup>> watchGroups(int dayId) {
    return (_db.select(_db.supersetGroups)
          ..where((g) => g.workoutDayId.equals(dayId))
          ..orderBy([(g) => OrderingTerm.asc(g.orderIndex)]))
        .watch();
  }

  Future<List<ExercisePrescription>> _dayRows(int dayId) {
    return (_db.select(_db.exercisePrescriptions)
          ..where((p) => p.workoutDayId.equals(dayId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.orderIndex),
            (p) => OrderingTerm.asc(p.id),
          ]))
        .get();
  }

  /// Groups [prescriptionIds] (at least 2) into a new superset. They must be
  /// single exercises of the day that sit next to each other. Rounds are taken
  /// from the first one and applied to all members.
  Future<int> createGroup(int dayId, List<int> prescriptionIds) {
    return _db.transaction(() async {
      if (prescriptionIds.length < 2) {
        throw ArgumentError.value(
            prescriptionIds, 'prescriptionIds', 'a superset needs 2+ exercises');
      }
      final entries =
          toEntries(await _dayRows(dayId), (p) => p.supersetGroupId);
      final positions = [
        for (final id in prescriptionIds)
          entries.indexWhere((e) => e.length == 1 && e.first.id == id),
      ]..sort();
      if (positions.first < 0 ||
          positions.toSet().length != positions.length ||
          [for (var i = 0; i < positions.length; i++) positions[i] - positions[0] - i]
              .any((d) => d != 0)) {
        throw ArgumentError(
            'Exercises must be ungrouped and next to each other in this day.');
      }
      final members = [for (final pos in positions) entries[pos].first];
      final rounds = members.first.targetSets;
      final groupId = await _db.into(_db.supersetGroups).insert(
            SupersetGroupsCompanion.insert(
              workoutDayId: dayId,
              orderIndex: positions.first,
              rounds: Value(rounds),
            ),
          );
      for (var i = 0; i < members.length; i++) {
        await (_db.update(_db.exercisePrescriptions)
              ..where((p) => p.id.equals(members[i].id)))
            .write(ExercisePrescriptionsCompanion(
          supersetGroupId: Value(groupId),
          supersetOrder: Value(i),
          targetSets: Value(rounds),
        ));
      }
      await _structure.normalize(dayId);
      return groupId;
    });
  }

  /// Adds a new exercise at the end of the group (sets = group rounds).
  Future<int> addMember(int groupId, PrescriptionDraft draft) {
    return _db.transaction(() async {
      draft.validate();
      final group = await (_db.select(_db.supersetGroups)
            ..where((g) => g.id.equals(groupId)))
          .getSingle();
      final members = await (_db.select(_db.exercisePrescriptions)
            ..where((p) => p.supersetGroupId.equals(groupId)))
          .get();
      final notes = draft.notes?.trim();
      final id = await _db.into(_db.exercisePrescriptions).insert(
            ExercisePrescriptionsCompanion.insert(
              workoutDayId: group.workoutDayId,
              exerciseId: draft.exerciseId,
              // Placeholder; normalize() moves it next to its group.
              orderIndex: 1 << 20,
              targetSets: Value(group.rounds),
              targetReps: Value(draft.targetReps),
              repScheme: Value(formatRepScheme(draft.repScheme)),
              targetWeightKg: Value(draft.targetWeightKg),
              setType: Value(draft.setType),
              restSeconds: Value(draft.restSeconds),
              notes: Value(notes == null || notes.isEmpty ? null : notes),
              supersetGroupId: Value(groupId),
              supersetOrder: Value(members.length),
            ),
          );
      await _structure.normalize(group.workoutDayId);
      return id;
    });
  }

  /// Takes one exercise out of its superset (it stays in the day). A group
  /// left with fewer than 2 members is dissolved.
  Future<void> removeMember(int prescriptionId) {
    return _db.transaction(() async {
      final p = await (_db.select(_db.exercisePrescriptions)
            ..where((x) => x.id.equals(prescriptionId)))
          .getSingleOrNull();
      if (p == null || p.supersetGroupId == null) return;
      await (_db.update(_db.exercisePrescriptions)
            ..where((x) => x.id.equals(prescriptionId)))
          .write(const ExercisePrescriptionsCompanion(
        supersetGroupId: Value(null),
        supersetOrder: Value(null),
      ));
      await _structure.normalize(p.workoutDayId);
    });
  }

  /// Dissolves the group; all members stay as single exercises in order.
  Future<void> ungroup(int groupId) {
    return _db.transaction(() async {
      final group = await (_db.select(_db.supersetGroups)
            ..where((g) => g.id.equals(groupId)))
          .getSingleOrNull();
      if (group == null) return;
      await (_db.update(_db.exercisePrescriptions)
            ..where((p) => p.supersetGroupId.equals(groupId)))
          .write(const ExercisePrescriptionsCompanion(
        supersetGroupId: Value(null),
        supersetOrder: Value(null),
      ));
      await (_db.delete(_db.supersetGroups)..where((g) => g.id.equals(groupId)))
          .go();
      await _structure.normalize(group.workoutDayId);
    });
  }

  /// Moves a member up (delta -1) or down (+1) inside its group.
  Future<void> moveMember(int prescriptionId, int delta) {
    return _db.transaction(() async {
      final p = await (_db.select(_db.exercisePrescriptions)
            ..where((x) => x.id.equals(prescriptionId)))
          .getSingleOrNull();
      final gid = p?.supersetGroupId;
      if (p == null || gid == null) return;
      final members = await (_db.select(_db.exercisePrescriptions)
            ..where((x) => x.supersetGroupId.equals(gid))
            ..orderBy([
              (x) => OrderingTerm.asc(x.supersetOrder),
              (x) => OrderingTerm.asc(x.id),
            ]))
          .get();
      final from = members.indexWhere((m) => m.id == prescriptionId);
      final to = from + delta;
      if (to < 0 || to >= members.length) return;
      members.insert(to, members.removeAt(from));
      for (var i = 0; i < members.length; i++) {
        await (_db.update(_db.exercisePrescriptions)
              ..where((x) => x.id.equals(members[i].id)))
            .write(ExercisePrescriptionsCompanion(supersetOrder: Value(i)));
      }
      await _structure.normalize(p.workoutDayId);
    });
  }

  /// Updates the group; [rounds] is applied to every member as its set count.
  Future<void> updateGroup(
    int groupId, {
    String? name,
    required int rounds,
    int? restBetweenSeconds,
    int? restAfterRoundSeconds,
  }) {
    if (rounds < 1) {
      throw ArgumentError.value(rounds, 'rounds', 'must be >= 1');
    }
    if ((restBetweenSeconds ?? 0) < 0 || (restAfterRoundSeconds ?? 0) < 0) {
      throw ArgumentError('Rest must be >= 0');
    }
    return _db.transaction(() async {
      final trimmed = name?.trim();
      await (_db.update(_db.supersetGroups)..where((g) => g.id.equals(groupId)))
          .write(SupersetGroupsCompanion(
        name: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        rounds: Value(rounds),
        restBetweenSeconds: Value(restBetweenSeconds),
        restAfterRoundSeconds: Value(restAfterRoundSeconds),
      ));
      await (_db.update(_db.exercisePrescriptions)
            ..where((p) => p.supersetGroupId.equals(groupId)))
          .write(ExercisePrescriptionsCompanion(targetSets: Value(rounds)));
    });
  }

  /// Reorders whole day entries. Keys are 'p<id>' for a single exercise and
  /// 'g<id>' for a superset; a superset moves as one unit.
  Future<void> reorderEntries(int dayId, List<String> orderedKeys) {
    return _db.transaction(() async {
      final entries =
          toEntries(await _dayRows(dayId), (p) => p.supersetGroupId);
      String keyOf(List<ExercisePrescription> e) => e.first.supersetGroupId != null
          ? 'g${e.first.supersetGroupId}'
          : 'p${e.first.id}';
      final byKey = {for (final e in entries) keyOf(e): e};
      if (orderedKeys.length != byKey.length ||
          !orderedKeys.every(byKey.containsKey)) {
        throw ArgumentError.value(
            orderedKeys, 'orderedKeys', 'must list every entry of the day once');
      }
      var index = 0;
      for (var entryPos = 0; entryPos < orderedKeys.length; entryPos++) {
        final members = byKey[orderedKeys[entryPos]]!;
        for (final m in members) {
          await (_db.update(_db.exercisePrescriptions)
                ..where((x) => x.id.equals(m.id)))
              .write(ExercisePrescriptionsCompanion(orderIndex: Value(index++)));
        }
        final gid = members.first.supersetGroupId;
        if (gid != null) {
          await (_db.update(_db.supersetGroups)..where((g) => g.id.equals(gid)))
              .write(SupersetGroupsCompanion(orderIndex: Value(entryPos)));
        }
      }
    });
  }
}
