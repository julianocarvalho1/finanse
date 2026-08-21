import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/planning/data/monthly_plan_repository.dart';
import 'package:finanse/features/planning/domain/monthly_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MonthlyPlanRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE ${AppDatabase.monthlyPlansTable} (
        yearMonth TEXT PRIMARY KEY,
        spendingLimitCents INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    repository = MonthlyPlanRepository(database: database);
  });

  tearDown(() => database.close());

  test('cada mês preserva o próprio limite', () async {
    await repository.saveLimit(
      month: DateTime(2026, 8),
      spendingLimitCents: 200000,
    );
    await repository.saveLimit(
      month: DateTime(2026, 9),
      spendingLimitCents: 180000,
    );

    expect(
      (await repository.getPlanForMonth(DateTime(2026, 8)))?.spendingLimitCents,
      200000,
    );
    expect(
      (await repository.getPlanForMonth(DateTime(2026, 9)))?.spendingLimitCents,
      180000,
    );
  });

  test('migra limite legado uma única vez sem sobrescrever o atual', () async {
    final MonthlyPlan? migrated = await repository.migrateLegacyLimit(
      month: DateTime(2026, 8),
      legacyLimit: 2000.45,
    );
    final MonthlyPlan? preserved = await repository.migrateLegacyLimit(
      month: DateTime(2026, 8),
      legacyLimit: 9000,
    );

    expect(migrated?.spendingLimitCents, 200045);
    expect(preserved?.spendingLimitCents, 200045);
  });
}
