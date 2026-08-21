import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/monthly_plan.dart';

class MonthlyPlanRepository {
  MonthlyPlanRepository({AppDatabase? appDatabase, Database? database})
    : assert(
        appDatabase == null || database == null,
        'Informe AppDatabase ou Database, não os dois.',
      ),
      _appDatabase = appDatabase ?? AppDatabase.instance,
      _injectedDatabase = database;

  final AppDatabase _appDatabase;
  final Database? _injectedDatabase;

  Future<Database> get _database async {
    return _injectedDatabase ?? _appDatabase.database;
  }

  Future<MonthlyPlan?> getPlanForMonth(DateTime month) async {
    final Database database = await _database;
    final List<Map<String, Object?>> rows = await database.query(
      AppDatabase.monthlyPlansTable,
      where: 'yearMonth = ?',
      whereArgs: <Object?>[MonthlyPlan.keyFor(month)],
      limit: 1,
    );

    return rows.isEmpty ? null : MonthlyPlan.fromMap(rows.first);
  }

  Future<MonthlyPlan> saveLimit({
    required DateTime month,
    required int spendingLimitCents,
  }) async {
    if (spendingLimitCents <= 0) {
      throw ArgumentError.value(
        spendingLimitCents,
        'spendingLimitCents',
        'Use um limite maior que zero.',
      );
    }

    final Database database = await _database;
    final MonthlyPlan? existing = await getPlanForMonth(month);
    final DateTime now = DateTime.now();
    final MonthlyPlan plan = MonthlyPlan(
      yearMonth: MonthlyPlan.keyFor(month),
      spendingLimitCents: spendingLimitCents,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await database.insert(
      AppDatabase.monthlyPlansTable,
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return plan;
  }

  Future<void> deletePlanForMonth(DateTime month) async {
    final Database database = await _database;
    await database.delete(
      AppDatabase.monthlyPlansTable,
      where: 'yearMonth = ?',
      whereArgs: <Object?>[MonthlyPlan.keyFor(month)],
    );
  }

  Future<MonthlyPlan?> migrateLegacyLimit({
    required DateTime month,
    required double? legacyLimit,
  }) async {
    final MonthlyPlan? existing = await getPlanForMonth(month);
    if (existing != null || legacyLimit == null || legacyLimit <= 0) {
      return existing;
    }

    return saveLimit(
      month: month,
      spendingLimitCents: (legacyLimit * 100).round(),
    );
  }
}
