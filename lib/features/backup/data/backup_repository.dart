import '../../../core/database/app_database.dart';
import '../domain/backup_format.dart';

/// What a restore brought in (for the confirmation message).
class RestoreSummary {
  const RestoreSummary(
      {required this.exercises, required this.programs, required this.sessions});

  final int exercises;
  final int programs;
  final int sessions;
}

class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// All data as a JSON string. Read in one transaction so the backup is a
  /// consistent snapshot even if the app writes at the same time.
  Future<String> exportJson() {
    return _db.transaction(() async {
      final contents = BackupContents(
        exercises: await _db.select(_db.exercises).get(),
        programs: await _db.select(_db.programs).get(),
        workoutDays: await _db.select(_db.workoutDays).get(),
        supersetGroups: await _db.select(_db.supersetGroups).get(),
        exercisePrescriptions:
            await _db.select(_db.exercisePrescriptions).get(),
        workoutSessions: await _db.select(_db.workoutSessions).get(),
        setLogs: await _db.select(_db.setLogs).get(),
        miniSetLogs: await _db.select(_db.miniSetLogs).get(),
      );
      return encodeBackup(
        contents,
        exportedAt: DateTime.now(),
        schemaVersion: _db.schemaVersion,
      );
    });
  }

  /// Replaces ALL current data with the backup. The file is fully parsed and
  /// validated first, and the replacement runs in one transaction, so a bad
  /// file or a failure midway leaves the existing data untouched.
  Future<RestoreSummary> restoreJson(String text) async {
    final c = decodeBackup(text, maxSchemaVersion: _db.schemaVersion);
    await _db.transaction(() async {
      // Children first so foreign keys are never violated.
      await _db.delete(_db.miniSetLogs).go();
      await _db.delete(_db.setLogs).go();
      await _db.delete(_db.workoutSessions).go();
      await _db.delete(_db.exercisePrescriptions).go();
      await _db.delete(_db.supersetGroups).go();
      await _db.delete(_db.workoutDays).go();
      await _db.delete(_db.programs).go();
      await _db.delete(_db.exercises).go();

      // Parents first when inserting. Ids are kept, so every reference stays
      // valid.
      await _db.batch((b) {
        b.insertAll(_db.exercises, c.exercises);
        b.insertAll(_db.programs, c.programs);
        b.insertAll(_db.workoutDays, c.workoutDays);
        b.insertAll(_db.supersetGroups, c.supersetGroups);
        b.insertAll(_db.exercisePrescriptions, c.exercisePrescriptions);
        b.insertAll(_db.workoutSessions, c.workoutSessions);
        b.insertAll(_db.setLogs, c.setLogs);
        b.insertAll(_db.miniSetLogs, c.miniSetLogs);
      });
    });
    return RestoreSummary(
      exercises: c.exercises.length,
      programs: c.programs.length,
      sessions: c.workoutSessions.length,
    );
  }
}
