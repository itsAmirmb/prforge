import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/program_importer.dart';
import 'package:prforge/features/programs/domain/program_template.dart';

String template(List<Map<String, dynamic>> entries) => jsonEncode({
      'format': 'prforge-program',
      'version': 1,
      'name': 'P',
      'days': [
        {'name': 'D', 'entries': entries},
      ],
    });

void main() {
  group('repScheme in templates', () {
    test('parsed; reps defaults to the first value', () {
      final t = parseProgramTemplate(template([
        {'exercise': 'A', 'sets': 4, 'repScheme': [12, 10, 8, 8]},
      ]));
      final a = t.days.single.entries.single as TemplateExercise;
      expect(a.repScheme, [12, 10, 8, 8]);
      expect(a.reps, 12);
    });

    test('a single value is just the target reps', () {
      final a = parseProgramTemplate(template([
        {'exercise': 'A', 'sets': 3, 'repScheme': [10]},
      ])).days.single.entries.single as TemplateExercise;
      expect(a.repScheme, isNull);
      expect(a.reps, 10);
    });

    test('invalid schemes are rejected', () {
      for (final bad in [[], [0, 5], ['x'], 'text']) {
        expect(
            () => parseProgramTemplate(template([
                  {'exercise': 'A', 'sets': 3, 'repScheme': bad},
                ])),
            throwsA(isA<ProgramTemplateException>()),
            reason: '$bad');
      }
    });
  });

  group('import', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('stores the scheme on the prescription (also in a superset)',
        () async {
      await ProgramImporter(db).importJson(template([
        {'exercise': 'A', 'sets': 4, 'repScheme': [12, 10, 8, 8]},
        {
          'rounds': 2,
          'superset': [
            {'exercise': 'B', 'repScheme': [12, 10]},
            {'exercise': 'C', 'reps': 10},
          ],
        },
      ]));
      final rows = await (db.select(db.exercisePrescriptions)
            ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
          .get();
      expect(rows.map((p) => p.repScheme), ['12,10,8,8', '12,10', isNull]);
      expect(rows.map((p) => p.targetReps), [12, 12, 10]);
    });

    test('the bundled 3-day program carries its rep schemes', () async {
      final text = File('test/fixtures/program_3day.json').readAsStringSync();
      await ProgramImporter(db).importJson(text);
      final rows = await db.select(db.exercisePrescriptions).get();
      final withScheme = rows.where((p) => p.repScheme != null).toList();
      expect(withScheme, hasLength(11));
      expect(withScheme.map((p) => p.repScheme), contains('8,8,10,12'));
      expect(withScheme.map((p) => p.repScheme), contains('15,12,10,8'));
    });
  });
}
