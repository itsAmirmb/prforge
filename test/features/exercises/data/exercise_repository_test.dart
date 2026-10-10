import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/exercises/data/exercise_repository.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExerciseRepository(db);
  });

  tearDown(() => db.close());

  Future<List<Exercise>> active() => repo.watchExercises(archived: false).first;
  Future<List<Exercise>> archived() => repo.watchExercises(archived: true).first;

  test('add trims name, blanks become null, list is sorted case-insensitively',
      () async {
    await repo.add(name: '  squat ', category: '  ');
    await repo.add(name: 'Curl', equipment: 'Dumbbell');
    final list = await active();
    expect(list.map((e) => e.name), ['Curl', 'squat']);
    expect(list.last.category, isNull);
  });

  test('blank name is rejected', () {
    expect(() => repo.add(name: '   '), throwsArgumentError);
  });

  test('update keeps id and can clear optional fields', () async {
    final id = await repo.add(name: 'Curl', category: 'Arms');
    await repo.update(id, name: 'Hammer Curl', isBodyweight: false);
    final e = (await active()).single;
    expect(e.id, id);
    expect(e.name, 'Hammer Curl');
    expect(e.category, isNull);
  });

  test('archive hides from active list, restore brings it back', () async {
    final id = await repo.add(name: 'Curl');
    await repo.setArchived(id, true);
    expect(await active(), isEmpty);
    expect((await archived()).single.id, id);
    await repo.setArchived(id, false);
    expect((await active()).single.id, id);
  });
}
