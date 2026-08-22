import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../planning/domain/monthly_plan.dart';
import '../domain/category_limit.dart';

class CategoryLimitRepository {
  CategoryLimitRepository({AppDatabase? appDatabase, Database? database})
    : assert(appDatabase == null || database == null),
      _appDatabase = appDatabase ?? AppDatabase.instance,
      _injectedDatabase = database;

  final AppDatabase _appDatabase;
  final Database? _injectedDatabase;

  Future<Database> get _database async =>
      _injectedDatabase ?? _appDatabase.database;

  Future<List<CategoryLimit>> getLimitsForMonth(DateTime month) async {
    final Database database = await _database;
    final List<Map<String, Object?>> rows = await database.query(
      AppDatabase.categoryLimitsTable,
      where: 'yearMonth = ?',
      whereArgs: <Object?>[MonthlyPlan.keyFor(month)],
      orderBy: 'categoryName COLLATE NOCASE',
    );
    return rows
        .map<CategoryLimit>(CategoryLimit.fromMap)
        .toList(growable: false);
  }

  Future<CategoryLimit> saveLimit({
    required DateTime month,
    required String categoryName,
    required int limitCents,
    required int warningPercent,
  }) async {
    final String normalizedCategory = categoryName.trim();
    if (normalizedCategory.isEmpty || limitCents <= 0) {
      throw ArgumentError('Informe a categoria e um limite válido.');
    }
    if (warningPercent < 50 || warningPercent > 100) {
      throw ArgumentError('Use um alerta entre 50% e 100%.');
    }
    final Database database = await _database;
    final String yearMonth = MonthlyPlan.keyFor(month);
    final List<Map<String, Object?>> existingRows = await database.query(
      AppDatabase.categoryLimitsTable,
      where: 'yearMonth = ? AND categoryName = ?',
      whereArgs: <Object?>[yearMonth, normalizedCategory],
      limit: 1,
    );
    final CategoryLimit? existing = existingRows.isEmpty
        ? null
        : CategoryLimit.fromMap(existingRows.first);

    final List<Map<String, Object?>> planRows = await database.query(
      AppDatabase.monthlyPlansTable,
      columns: <String>['spendingLimitCents'],
      where: 'yearMonth = ?',
      whereArgs: <Object?>[yearMonth],
      limit: 1,
    );
    if (planRows.isNotEmpty) {
      final List<Map<String, Object?>> totalRows = await database.rawQuery(
        '''
        SELECT COALESCE(SUM(limitCents), 0) AS total
        FROM ${AppDatabase.categoryLimitsTable}
        WHERE yearMonth = ? AND categoryName != ?
        ''',
        <Object?>[yearMonth, normalizedCategory],
      );
      final int otherLimits =
          (totalRows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
      final int generalLimit = (planRows.first['spendingLimitCents'] as num)
          .toInt();
      if (otherLimits + limitCents > generalLimit) {
        throw StateError(
          'A soma dos limites por categoria precisa caber no limite geral.',
        );
      }
    }

    final DateTime now = DateTime.now();
    final CategoryLimit limit = CategoryLimit(
      yearMonth: yearMonth,
      categoryName: normalizedCategory,
      limitCents: limitCents,
      warningPercent: warningPercent,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await database.insert(
      AppDatabase.categoryLimitsTable,
      limit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return limit;
  }

  Future<void> deleteLimit(DateTime month, String categoryName) async {
    final Database database = await _database;
    await database.delete(
      AppDatabase.categoryLimitsTable,
      where: 'yearMonth = ? AND categoryName = ?',
      whereArgs: <Object?>[MonthlyPlan.keyFor(month), categoryName.trim()],
    );
  }

  Future<List<CategoryLimitSummary>> getSummariesForMonth(
    DateTime month,
  ) async {
    final Database database = await _database;
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);
    final DateTime previousStart = DateTime(month.year, month.month - 1);

    final List<CategoryLimit> limits = await getLimitsForMonth(month);
    final Map<String, int> current = await _totalsByCategory(
      database,
      start,
      end,
    );
    final Map<String, int> previous = await _totalsByCategory(
      database,
      previousStart,
      start,
    );
    final Map<String, CategoryLimit> limitsByCategory = <String, CategoryLimit>{
      for (final CategoryLimit limit in limits) limit.categoryName: limit,
    };
    final Set<String> categories = <String>{
      ...current.keys,
      ...previous.keys,
      ...limitsByCategory.keys,
    };
    final List<CategoryLimitSummary> summaries =
        categories
            .map((String category) {
              return CategoryLimitSummary(
                categoryName: category,
                spentCents: current[category] ?? 0,
                previousSpentCents: previous[category] ?? 0,
                limit: limitsByCategory[category],
              );
            })
            .toList(growable: false)
          ..sort((CategoryLimitSummary first, CategoryLimitSummary second) {
            if (first.limit != null && second.limit == null) return -1;
            if (first.limit == null && second.limit != null) return 1;
            return second.spentCents.compareTo(first.spentCents);
          });
    return summaries;
  }

  Future<Map<String, int>> _totalsByCategory(
    Database database,
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT categoryName, COALESCE(SUM(amount), 0) AS total
      FROM ${AppDatabase.expensesTable}
      WHERE date >= ? AND date < ?
      GROUP BY categoryName
      ''',
      <Object?>[start.toIso8601String(), end.toIso8601String()],
    );
    return <String, int>{
      for (final Map<String, Object?> row in rows)
        row['categoryName'].toString():
            (((row['total'] as num?)?.toDouble() ?? 0) * 100).round(),
    };
  }
}
