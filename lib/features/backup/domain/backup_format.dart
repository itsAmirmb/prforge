import 'dart:convert';

import '../../../core/database/app_database.dart';

const backupFormatName = 'prforge-backup';

/// Version of the JSON layout (separate from the database schema version).
const backupFormatVersion = 1;

/// A backup cannot be read or is not compatible with this app.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every row of every table. Weights are kg, dates are epoch milliseconds,
/// enums are their stored int (drift's default JSON serialization).
class BackupContents {
  const BackupContents({
    required this.exercises,
    required this.programs,
    required this.workoutDays,
    required this.supersetGroups,
    required this.exercisePrescriptions,
    required this.workoutSessions,
    required this.setLogs,
    required this.miniSetLogs,
  });

  final List<Exercise> exercises;
  final List<Program> programs;
  final List<WorkoutDay> workoutDays;
  final List<SupersetGroup> supersetGroups;
  final List<ExercisePrescription> exercisePrescriptions;
  final List<WorkoutSession> workoutSessions;
  final List<SetLog> setLogs;
  final List<MiniSetLog> miniSetLogs;
}

String encodeBackup(
  BackupContents c, {
  required DateTime exportedAt,
  required int schemaVersion,
}) {
  List<Map<String, dynamic>> rows<T>(
          List<T> list, Map<String, dynamic> Function(T) toJson) =>
      [for (final r in list) toJson(r)];

  return const JsonEncoder.withIndent(' ').convert({
    'format': backupFormatName,
    'version': backupFormatVersion,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'tables': {
      'exercises': rows<Exercise>(c.exercises, (r) => r.toJson()),
      'programs': rows<Program>(c.programs, (r) => r.toJson()),
      'workoutDays': rows<WorkoutDay>(c.workoutDays, (r) => r.toJson()),
      'supersetGroups':
          rows<SupersetGroup>(c.supersetGroups, (r) => r.toJson()),
      'exercisePrescriptions': rows<ExercisePrescription>(
          c.exercisePrescriptions, (r) => r.toJson()),
      'workoutSessions':
          rows<WorkoutSession>(c.workoutSessions, (r) => r.toJson()),
      'setLogs': rows<SetLog>(c.setLogs, (r) => r.toJson()),
      'miniSetLogs': rows<MiniSetLog>(c.miniSetLogs, (r) => r.toJson()),
    },
  });
}

/// Parses and validates a backup completely before anything is restored.
/// Throws [BackupFormatException] with a readable message on any problem.
BackupContents decodeBackup(String text, {required int maxSchemaVersion}) {
  final Object? root;
  try {
    root = jsonDecode(text.startsWith('﻿') ? text.substring(1) : text);
  } on FormatException {
    throw const BackupFormatException('This file is not valid JSON.');
  }
  if (root is! Map<String, dynamic> || root['format'] != backupFormatName) {
    throw const BackupFormatException('This is not a PRForge backup file.');
  }
  final version = root['version'];
  if (version is! int || version > backupFormatVersion) {
    throw const BackupFormatException(
        'This backup was made by a newer version of the app.');
  }
  final schema = root['schemaVersion'];
  if (schema is! int || schema > maxSchemaVersion) {
    throw const BackupFormatException(
        'This backup was made by a newer version of the app.');
  }
  final tables = root['tables'];
  if (tables is! Map<String, dynamic>) {
    throw const BackupFormatException('The backup has no data.');
  }

  List<T> read<T>(String name, T Function(Map<String, dynamic>) fromJson) {
    final raw = tables[name];
    if (raw is! List) {
      throw BackupFormatException('The backup is missing "$name".');
    }
    try {
      return [for (final r in raw) fromJson(r as Map<String, dynamic>)];
    } catch (_) {
      throw BackupFormatException('The backup has damaged data in "$name".');
    }
  }

  return BackupContents(
    exercises: read('exercises', Exercise.fromJson),
    programs: read('programs', Program.fromJson),
    workoutDays: read('workoutDays', WorkoutDay.fromJson),
    supersetGroups: read('supersetGroups', SupersetGroup.fromJson),
    exercisePrescriptions:
        read('exercisePrescriptions', ExercisePrescription.fromJson),
    workoutSessions: read('workoutSessions', WorkoutSession.fromJson),
    setLogs: read('setLogs', SetLog.fromJson),
    miniSetLogs: read('miniSetLogs', MiniSetLog.fromJson),
  );
}
