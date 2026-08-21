import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/category_limits/data/category_limit_repository.dart';
import 'package:finanse/features/category_limits/domain/category_limit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late CategoryLimitRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE ${AppDatabase.expensesTable} (
        id TEXT PRIMARY KEY, amount REAL NOT NULL, categoryName TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppDatabase.monthlyPlansTable} (
        yearMonth TEXT PRIMARY KEY, spendingLimitCents INTEGER NOT NULL,
        warningPercent INTEGER NOT NULL DEFAULT 70,
        createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppDatabase.categoryLimitsTable} (
        yearMonth TEXT NOT NULL, categoryName TEXT NOT NULL,
        limitCents INTEGER NOT NULL, warningPercent INTEGER NOT NULL,
        createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL,
        PRIMARY KEY(yearMonth, categoryName)
      )
    ''');
    repository = CategoryLimitRepository(database: database);
  });

  tearDown(() => database.close());

  test('calcula alerta, excesso e comparação com mês anterior', () async {
    await repository.saveLimit(
      month: DateTime(2026, 8),
      categoryName: 'Alimentação',
      limitCents: 100000,
      warningPercent: 70,
    );
    await _expense(database, 'july', 900, DateTime(2026, 7, 10));
    await _expense(database, 'august', 750, DateTime(2026, 8, 10));

    CategoryLimitSummary summary = (await repository.getSummariesForMonth(
      DateTime(2026, 8),
    )).single;
    expect(summary.status, CategoryLimitStatus.attention);
    expect(summary.differenceCents, -15000);

    await _expense(database, 'august-2', 400, DateTime(2026, 8, 12));
    summary = (await repository.getSummariesForMonth(DateTime(2026, 8))).single;
    expect(summary.status, CategoryLimitStatus.exceeded);
    expect(summary.availableCents, 0);
  });

  test('não deixa a soma das categorias ultrapassar o limite geral', () async {
    final DateTime now = DateTime(2026, 8, 1);
    await database.insert(AppDatabase.monthlyPlansTable, <String, Object?>{
      'yearMonth': '2026-08',
      'spendingLimitCents': 200000,
      'warningPercent': 70,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    await repository.saveLimit(
      month: now,
      categoryName: 'Moradia',
      limitCents: 150000,
      warningPercent: 80,
    );

    await expectLater(
      repository.saveLimit(
        month: now,
        categoryName: 'Lazer',
        limitCents: 60000,
        warningPercent: 80,
      ),
      throwsStateError,
    );
  });
}

Future<void> _expense(
  Database database,
  String id,
  double amount,
  DateTime date,
) {
  return database.insert(AppDatabase.expensesTable, <String, Object?>{
    'id': id,
    'amount': amount,
    'categoryName': 'Alimentação',
    'date': date.toIso8601String(),
  });
}
