import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Program persistence. Programs are archived, never deleted, so sessions
/// that reference them stay valid.
class ProgramRepository {
  ProgramRepository(this._db);

  final AppDatabase _db;

  Stream<List<Program>> watchPrograms({required bool archived}) {
    final query = _db.select(_db.programs)
      ..where((p) => p.isArchived.equals(archived))
      ..orderBy([(p) => OrderingTerm.asc(p.name.collate(Collate.noCase))]);
    return query.watch();
  }

  Stream<Program?> watchProgram(int id) {
    return (_db.select(_db.programs)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<int> add(String name) {
    return _db
        .into(_db.programs)
        .insert(ProgramsCompanion.insert(name: _requireName(name)));
  }

  Future<void> rename(int id, String name) async {
    await (_db.update(_db.programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(
        name: Value(_requireName(name)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setArchived(int id, bool archived) async {
    await (_db.update(_db.programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return trimmed;
  }
}
