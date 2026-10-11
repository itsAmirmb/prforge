import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/domain/program_template.dart';

Map<String, dynamic> valid() => {
      'format': programTemplateFormat,
      'version': 1,
      'name': 'P',
      'days': [
        {
          'name': 'D',
          'entries': [
            {'exercise': 'Bench', 'sets': 4, 'reps': 8, 'weightKg': 60},
            {
              'rounds': 3,
              'superset': [
                {'exercise': 'A', 'reps': 12},
                {'exercise': 'B', 'reps': 10, 'notes': ' x '},
              ],
            },
          ],
        },
      ],
    };

ProgramTemplate parse(Map<String, dynamic> m) =>
    parseProgramTemplate(jsonEncode(m));

void expectInvalid(Map<String, dynamic> m) =>
    expect(() => parse(m), throwsA(isA<ProgramTemplateException>()));

void main() {
  test('parses exercises and supersets', () {
    final t = parse(valid());
    expect(t.name, 'P');
    final entries = t.days.single.entries;
    final bench = entries[0] as TemplateExercise;
    expect(bench.sets, 4);
    expect(bench.reps, 8);
    expect(bench.weightKg, 60);
    expect(bench.type, SetKind.normal);
    final ss = entries[1] as TemplateSuperset;
    expect(ss.rounds, 3);
    expect(ss.members.map((m) => m.name), ['A', 'B']);
    expect(ss.members.every((m) => m.sets == 3), isTrue);
    expect(ss.members[1].notes, 'x');
  });

  test('set type by name', () {
    final m = valid();
    ((m['days'] as List).first['entries'] as List).first['type'] = 'restPause';
    final first = parse(m).days.first.entries.first as TemplateExercise;
    expect(first.type, SetKind.restPause);
  });

  test('rejects broken files', () {
    expect(() => parseProgramTemplate('nope'),
        throwsA(isA<ProgramTemplateException>()));
    expectInvalid({'format': 'other'});
    expectInvalid({...valid(), 'version': 2});
    expectInvalid({...valid(), 'days': []});
    expectInvalid({...valid(), 'name': '  '});
  });

  test('rejects invalid values', () {
    List entries(Map<String, dynamic> m) =>
        (m['days'] as List).first['entries'] as List;

    var m = valid();
    entries(m).first['sets'] = 0;
    expectInvalid(m);

    m = valid();
    entries(m).first.remove('sets');
    expectInvalid(m);

    m = valid();
    entries(m).first['type'] = 'weird';
    expectInvalid(m);

    m = valid();
    entries(m).first['weightKg'] = -1;
    expectInvalid(m);

    m = valid();
    (entries(m)[1]['superset'] as List).removeLast();
    expectInvalid(m);

    m = valid();
    entries(m)[1].remove('rounds');
    expectInvalid(m);

    m = valid();
    entries(m).first['exercise'] = 'x' * 101;
    expectInvalid(m);
  });
}
