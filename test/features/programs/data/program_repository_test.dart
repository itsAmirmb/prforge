import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/program_repository.dart';

void main() {
  late AppDatabase db;
  late ProgramRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProgramRepository(db);
  });

  tearDown(() => db.close());

  Future<List<Program>> active() => repo.watchPrograms(archived: false).first;
  Future<List<Program>> archived() => repo.watchPrograms(archived: true).first;

  test('add trims name and lists programs sorted case-insensitively', () async {
    await repo.add('  push pull legs ');
    await repo.add('Arnold split');
    expect((await active()).map((p) => p.name), ['Arnold split', 'push pull legs']);
  });

  test('blank name is rejected on add and rename', () async {
    expect(() => repo.add('  '), throwsArgumentError);
    final id = await repo.add('A');
    expect(() => repo.rename(id, ''), throwsArgumentError);
  });

  test('rename keeps id', () async {
    final id = await repo.add('A');
    await repo.rename(id, 'B');
    final p = (await active()).single;
    expect(p.id, id);
    expect(p.name, 'B');
  });

  test('archive hides from active list and restore brings it back', () async {
    final id = await repo.add('A');
    await repo.setArchived(id, true);
    expect(await active(), isEmpty);
    expect((await archived()).single.id, id);
    await repo.setArchived(id, false);
    expect((await active()).single.id, id);
  });
}
