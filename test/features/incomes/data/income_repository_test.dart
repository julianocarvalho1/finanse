import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/incomes/data/income_repository.dart';
import 'package:finanse/features/incomes/domain/income.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late IncomeRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE ${AppDatabase.incomesTable} (
        id TEXT PRIMARY KEY,
        amountCents INTEGER NOT NULL,
        source TEXT NOT NULL,
        date TEXT NOT NULL,
        recurrence TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    repository = IncomeRepository(database: database);
  });

  tearDown(() => database.close());

  test('não mistura rendas únicas de meses diferentes', () async {
    await repository.insertIncome(_income('august', 120000, DateTime(2026, 8)));
    await repository.insertIncome(
      _income('september', 80000, DateTime(2026, 9)),
    );

    expect(await repository.getTotalCentsForMonth(DateTime(2026, 8)), 120000);
    expect(await repository.getTotalCentsForMonth(DateTime(2026, 9)), 80000);
  });

  test('inclui renda mensal nos meses seguintes sem duplicar linhas', () async {
    await repository.insertIncome(
      _income(
        'salary',
        500000,
        DateTime(2026, 8, 31),
        recurrence: IncomeRecurrence.monthly,
      ),
    );

    expect(await repository.getTotalCentsForMonth(DateTime(2026, 7)), 0);
    expect(await repository.getTotalCentsForMonth(DateTime(2026, 8)), 500000);
    expect(await repository.getTotalCentsForMonth(DateTime(2026, 9)), 500000);

    final List<Map<String, Object?>> countRows = await database.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppDatabase.incomesTable}',
    );
    final int rowCount = (countRows.first['total'] as num).toInt();
    expect(rowCount, 1);
  });

  test('editar e excluir renda atualiza o total', () async {
    final Income income = _income('extra', 10000, DateTime(2026, 8));
    await repository.insertIncome(income);
    await repository.updateIncome(
      income.copyWith(amountCents: 25000, updatedAt: DateTime(2026, 8, 2)),
    );
    expect(await repository.getTotalCentsForMonth(DateTime(2026, 8)), 25000);

    await repository.deleteIncome(income.id);
    expect(await repository.getTotalCentsForMonth(DateTime(2026, 8)), 0);
  });
}

Income _income(
  String id,
  int amountCents,
  DateTime date, {
  IncomeRecurrence recurrence = IncomeRecurrence.none,
}) {
  return Income(
    id: id,
    amountCents: amountCents,
    source: id,
    date: date,
    recurrence: recurrence,
    createdAt: date,
    updatedAt: date,
  );
}
