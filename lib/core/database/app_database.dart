import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart' show SetKind, SessionStatus;

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Exercises,
  Programs,
  WorkoutDays,
  SupersetGroups,
  ExercisePrescriptions,
  WorkoutSessions,
  SetLogs,
  MiniSetLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'prforge'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(
                exercisePrescriptions, exercisePrescriptions.repScheme);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
