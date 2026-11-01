import 'dart:convert';

import '../../../core/database/app_database.dart';

const programTemplateFormat = 'prforge-program';
const programTemplateVersion = 1;

/// The file is not a valid program template.
class ProgramTemplateException implements Exception {
  const ProgramTemplateException(this.message);

  final String message;

  @override
  String toString() => message;
}

sealed class TemplateEntry {
  const TemplateEntry();
}

/// One planned exercise. Inside a superset, [sets] equals the group's rounds.
class TemplateExercise extends TemplateEntry {
  const TemplateExercise({
    required this.name,
    required this.sets,
    this.reps,
    this.repScheme,
    this.weightKg,
    this.type = SetKind.normal,
    this.restSeconds,
    this.notes,
  });

  final String name;
  final int sets;
  final int? reps;

  /// Reps per set (e.g. [12, 10, 8, 8]); when given, [reps] is its first value.
  final List<int>? repScheme;
  final double? weightKg;
  final SetKind type;
  final int? restSeconds;
  final String? notes;
}

class TemplateSuperset extends TemplateEntry {
  const TemplateSuperset({required this.rounds, required this.members});

  final int rounds;
  final List<TemplateExercise> members;
}

class TemplateDay {
  const TemplateDay({required this.name, required this.entries});

  final String name;
  final List<TemplateEntry> entries;
}

class ProgramTemplate {
  const ProgramTemplate({required this.name, required this.days});

  final String name;
  final List<TemplateDay> days;
}

/// Parses and fully validates a program template before anything is saved.
///
/// ```json
/// {"format": "prforge-program", "version": 1, "name": "...",
///  "days": [{"name": "...", "entries": [
///    {"exercise": "Bench", "sets": 4, "reps": 8, "weightKg": 60,
///     "type": "restPause", "restSeconds": 90, "notes": "..."},
///    {"rounds": 3, "superset": [{"exercise": "A", "reps": 12},
///                               {"exercise": "B", "reps": 12}]}
///  ]}]}
/// ```
ProgramTemplate parseProgramTemplate(String text) {
  final Object? root;
  try {
    root = jsonDecode(text.startsWith('﻿') ? text.substring(1) : text);
  } on FormatException {
    throw const ProgramTemplateException('This file is not valid JSON.');
  }
  if (root is! Map<String, dynamic> || root['format'] != programTemplateFormat) {
    throw const ProgramTemplateException('This is not a PRForge program file.');
  }
  final version = root['version'];
  if (version is! int || version > programTemplateVersion) {
    throw const ProgramTemplateException(
        'This program file was made for a newer version of the app.');
  }
  final days = root['days'];
  if (days is! List || days.isEmpty) {
    throw const ProgramTemplateException('The program has no days.');
  }
  return ProgramTemplate(
    name: _name(root, 'program'),
    days: [
      for (var i = 0; i < days.length; i++) _day(days[i], i + 1),
    ],
  );
}

String _name(Map<String, dynamic> map, String what) {
  final raw = map['name'] ?? map['exercise'];
  if (raw is! String || raw.trim().isEmpty || raw.trim().length > 100) {
    throw ProgramTemplateException(
        'Every $what needs a name of 1–100 characters.');
  }
  return raw.trim();
}

int? _positive(Map<String, dynamic> map, String key, String where,
    {bool required = false}) {
  final value = map[key];
  if (value == null) {
    if (required) {
      throw ProgramTemplateException('$where: "$key" is required.');
    }
    return null;
  }
  if (value is! int || value < 1) {
    throw ProgramTemplateException('$where: "$key" must be a whole number ≥ 1.');
  }
  return value;
}

TemplateDay _day(Object? raw, int number) {
  if (raw is! Map<String, dynamic>) {
    throw ProgramTemplateException('Day $number is not valid.');
  }
  final entries = raw['entries'];
  if (entries is! List || entries.isEmpty) {
    throw ProgramTemplateException('Day $number has no exercises.');
  }
  return TemplateDay(
    name: _name(raw, 'day'),
    entries: [
      for (var i = 0; i < entries.length; i++)
        _entry(entries[i], 'Day $number, item ${i + 1}'),
    ],
  );
}

TemplateEntry _entry(Object? raw, String where) {
  if (raw is! Map<String, dynamic>) {
    throw ProgramTemplateException('$where is not valid.');
  }
  final superset = raw['superset'];
  if (superset == null) return _exercise(raw, where);

  if (superset is! List || superset.length < 2) {
    throw ProgramTemplateException('$where: a superset needs 2+ exercises.');
  }
  final rounds = _positive(raw, 'rounds', where, required: true)!;
  return TemplateSuperset(
    rounds: rounds,
    members: [
      for (var i = 0; i < superset.length; i++)
        _exercise(
          superset[i] is Map<String, dynamic>
              ? {...superset[i] as Map<String, dynamic>, 'sets': rounds}
              : <String, dynamic>{},
          '$where, member ${i + 1}',
        ),
    ],
  );
}

TemplateExercise _exercise(Map<String, dynamic> raw, String where) {
  final name = _name(raw, 'exercise');
  final weight = raw['weightKg'];
  if (weight != null && (weight is! num || weight < 0)) {
    throw ProgramTemplateException('$where: "weightKg" must be ≥ 0.');
  }
  final rest = raw['restSeconds'];
  if (rest != null && (rest is! int || rest < 0)) {
    throw ProgramTemplateException('$where: "restSeconds" must be ≥ 0.');
  }
  final typeName = raw['type'];
  final SetKind type;
  if (typeName == null) {
    type = SetKind.normal;
  } else {
    final match = SetKind.values.where((k) => k.name == typeName);
    if (match.isEmpty) {
      throw ProgramTemplateException(
          '$where: unknown type "$typeName" (use ${SetKind.values.map((k) => k.name).join(', ')}).');
    }
    type = match.first;
  }
  final schemeRaw = raw['repScheme'];
  List<int>? scheme;
  if (schemeRaw != null) {
    if (schemeRaw is! List ||
        schemeRaw.isEmpty ||
        schemeRaw.any((r) => r is! int || r < 1)) {
      throw ProgramTemplateException(
          '$where: "repScheme" must be a list of whole numbers ≥ 1.');
    }
    scheme = schemeRaw.cast<int>();
  }
  final notes = raw['notes'];
  if (notes != null && notes is! String) {
    throw ProgramTemplateException('$where: "notes" must be text.');
  }
  final cleanNotes = (notes as String?)?.trim();
  return TemplateExercise(
    name: name,
    sets: _positive(raw, 'sets', where, required: true)!,
    reps: _positive(raw, 'reps', where) ?? scheme?.first,
    repScheme: scheme != null && scheme.length > 1 ? scheme : null,
    weightKg: (weight as num?)?.toDouble(),
    type: type,
    restSeconds: rest as int?,
    notes: (cleanNotes == null || cleanNotes.isEmpty) ? null : cleanNotes,
  );
}
