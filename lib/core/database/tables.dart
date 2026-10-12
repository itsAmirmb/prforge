import 'package:drift/drift.dart';

/// Kind of a logged set. Stored as int index — only append new values at the end.
enum SetKind { normal, warmup, drop, restPause, amrap }

enum SessionStatus { inProgress, completed, cancelled }

// ───────── Program side (what is PLANNED) ─────────

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().nullable()();
  TextColumn get equipment => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isBodyweight => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class WorkoutDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get orderIndex => integer()();
}

class SupersetGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDayId => integer().references(WorkoutDays, #id)();
  TextColumn get name => text().nullable()();
  IntColumn get orderIndex => integer()();
  IntColumn get rounds => integer().withDefault(const Constant(3))();
  IntColumn get restBetweenSeconds => integer().nullable()();
  IntColumn get restAfterRoundSeconds => integer().nullable()();
}

class ExercisePrescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDayId => integer().references(WorkoutDays, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().nullable()();

  /// Optional reps per set, comma separated ("12,10,8,8"). When set it wins
  /// over [targetReps]; sets beyond the list reuse the last value.
  TextColumn get repScheme => text().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get setType => intEnum<SetKind>().withDefault(const Constant(0))();
  IntColumn get supersetGroupId =>
      integer().nullable().references(SupersetGroups, #id)();
  IntColumn get supersetOrder => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

// ───────── History side (what was ACTUALLY DONE) ─────────

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nullable on purpose: history must survive program changes.
  IntColumn get programId => integer().nullable().references(Programs, #id)();
  IntColumn get workoutDayId =>
      integer().nullable().references(WorkoutDays, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get status =>
      intEnum<SessionStatus>().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  // Direct link to the exercise: history never depends on a prescription.
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get prescriptionId =>
      integer().nullable().references(ExercisePrescriptions, #id)();
  IntColumn get setIndex => integer()();
  IntColumn get setKind => intEnum<SetKind>().withDefault(const Constant(0))();

  /// Always kg. null = no weight (bodyweight); 0 is a real value, not "unset".
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// When the set was marked done (null while not done, and for sets logged
  /// before this column existed). Feeds per-exercise start/end/duration.
  DateTimeColumn get completedAt => dateTime().nullable()();

  // Superset membership snapshot, so history keeps it after program edits.
  TextColumn get supersetKey => text().nullable()();
  IntColumn get roundIndex => integer().nullable()();

  /// Groups mini-sets of one rest-pause main set (optional for other kinds).
  IntColumn get mainSetId => integer().nullable()();
  TextColumn get note => text().nullable()();
}

class MiniSetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setLogId =>
      integer().references(SetLogs, #id, onDelete: KeyAction.cascade)();
  IntColumn get miniSetIndex => integer()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer()();
  IntColumn get restSeconds => integer().nullable()();
}

/// User settings as key/value text rows (see UserSettings for the keys).
/// Kept out of backups on purpose: they describe this device, not the data.
class SettingEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
