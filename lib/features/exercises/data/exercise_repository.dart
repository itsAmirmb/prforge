import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// All exercise persistence lives here; UI never touches the database.
/// Exercises are archived, never deleted, so history keeps its references.
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Exercise>> watchExercises({required bool archived}) {
    final query = _db.select(_db.exercises)
      ..where((e) => e.isArchived.equals(archived))
      ..orderBy([(e) => OrderingTerm.asc(e.name.collate(Collate.noCase))]);
    return query.watch();
  }

  Future<int> add({
    required String name,
    String? category,
    String? equipment,
    String? notes,
    bool isBodyweight = false,
  }) {
    return _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            name: _requireName(name),
            category: Value(_clean(category)),
            equipment: Value(_clean(equipment)),
            notes: Value(_clean(notes)),
            isBodyweight: Value(isBodyweight),
          ),
        );
  }

  Future<void> update(
    int id, {
    required String name,
    String? category,
    String? equipment,
    String? notes,
    required bool isBodyweight,
  }) async {
    await (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        name: Value(_requireName(name)),
        category: Value(_clean(category)),
        equipment: Value(_clean(equipment)),
        notes: Value(_clean(notes)),
        isBodyweight: Value(isBodyweight),
      ),
    );
  }

  Future<void> setArchived(int id, bool archived) async {
    await (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
        .write(ExercisesCompanion(isArchived: Value(archived)));
  }

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return trimmed;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
