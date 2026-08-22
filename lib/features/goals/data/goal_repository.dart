import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/goal_progress.dart';
import '../domain/goal_transaction.dart';
import '../domain/savings_goal.dart';

class GoalRepository {
  GoalRepository({AppDatabase? appDatabase, Database? database})
    : assert(appDatabase == null || database == null),
      _appDatabase = appDatabase ?? AppDatabase.instance,
      _injectedDatabase = database,
      _uuid = const Uuid();

  final AppDatabase _appDatabase;
  final Database? _injectedDatabase;
  final Uuid _uuid;

  Future<Database> get _database async =>
      _injectedDatabase ?? _appDatabase.database;

  Future<void> createGoal(SavingsGoal goal) async {
    _validateGoal(goal);
    final Database database = await _database;
    await database.insert(
      AppDatabase.savingsGoalsTable,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    _validateGoal(goal);
    final Database database = await _database;
    final int changed = await database.update(
      AppDatabase.savingsGoalsTable,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[goal.id],
    );
    if (changed == 0) {
      throw StateError('A meta não foi encontrada.');
    }
  }

  Future<List<GoalProgress>> getGoalsWithProgress() async {
    final Database database = await _database;
    final List<Map<String, Object?>> rows = await database.rawQuery('''
      SELECT g.*,
        COALESCE((
          SELECT t.balanceAfterCents
          FROM ${AppDatabase.goalTransactionsTable} t
          WHERE t.goalId = g.id
          ORDER BY t.createdAt DESC, t.rowid DESC
          LIMIT 1
        ), 0) AS savedCents
      FROM ${AppDatabase.savingsGoalsTable} g
      ORDER BY
        CASE g.status
          WHEN 'active' THEN 0
          WHEN 'paused' THEN 1
          ELSE 2
        END,
        g.updatedAt DESC
    ''');

    return rows
        .map<GoalProgress>((Map<String, Object?> row) {
          return GoalProgress(
            goal: SavingsGoal.fromMap(row),
            savedCents: (row['savedCents'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);
  }

  Future<GoalProgress?> getGoalProgress(String goalId) async {
    final List<GoalProgress> goals = await getGoalsWithProgress();
    return goals
        .where((GoalProgress item) => item.goal.id == goalId)
        .firstOrNull;
  }

  Future<List<GoalTransaction>> getTransactions(String goalId) async {
    final Database database = await _database;
    final List<Map<String, Object?>> rows = await database.query(
      AppDatabase.goalTransactionsTable,
      where: 'goalId = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'createdAt DESC, rowid DESC',
    );
    return rows
        .map<GoalTransaction>(GoalTransaction.fromMap)
        .toList(growable: false);
  }

  Future<GoalTransaction> allocate({
    required String goalId,
    required int amountCents,
    String? originYearMonth,
    String? note,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError('Use um valor maior que zero.');
    }
    return _recordChange(
      goalId: goalId,
      type: GoalTransactionType.allocation,
      changeCents: amountCents,
      originYearMonth: originYearMonth,
      note: note,
    );
  }

  Future<GoalTransaction> withdraw({
    required String goalId,
    required int amountCents,
    String? note,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError('Use um valor maior que zero.');
    }
    return _recordChange(
      goalId: goalId,
      type: GoalTransactionType.withdrawal,
      changeCents: -amountCents,
      note: note,
    );
  }

  Future<GoalTransaction> adjust({
    required String goalId,
    required int newBalanceCents,
    String? note,
  }) async {
    if (newBalanceCents < 0) {
      throw ArgumentError('A meta não pode ficar negativa.');
    }
    final Database database = await _database;
    final int currentBalance = await _currentBalance(database, goalId);
    final int change = newBalanceCents - currentBalance;
    if (change == 0) {
      throw StateError('O valor informado já é o saldo atual da meta.');
    }
    return _recordChange(
      goalId: goalId,
      type: GoalTransactionType.adjustment,
      changeCents: change,
      note: note,
    );
  }

  Future<int> getAllocatedCentsForMonth(String yearMonth) async {
    final Database database = await _database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(changeCents), 0) AS total
      FROM ${AppDatabase.goalTransactionsTable}
      WHERE type = 'allocation' AND originYearMonth = ?
      ''',
      <Object?>[yearMonth],
    );
    return (rows.firstOrNull?['total'] as num?)?.toInt() ?? 0;
  }

  Future<GoalTransaction> _recordChange({
    required String goalId,
    required GoalTransactionType type,
    required int changeCents,
    String? originYearMonth,
    String? note,
  }) async {
    final Database database = await _database;
    return database.transaction<GoalTransaction>((
      Transaction transaction,
    ) async {
      final List<Map<String, Object?>> goals = await transaction.query(
        AppDatabase.savingsGoalsTable,
        columns: <String>['id'],
        where: 'id = ?',
        whereArgs: <Object?>[goalId],
        limit: 1,
      );
      if (goals.isEmpty) {
        throw StateError('A meta não foi encontrada.');
      }
      final int currentBalance = await _currentBalance(transaction, goalId);
      final int newBalance = currentBalance + changeCents;
      if (newBalance < 0) {
        throw StateError('O valor é maior que o total guardado na meta.');
      }
      final DateTime now = DateTime.now();
      final GoalTransaction goalTransaction = GoalTransaction(
        id: _uuid.v4(),
        goalId: goalId,
        type: type,
        changeCents: changeCents,
        balanceAfterCents: newBalance,
        originYearMonth: originYearMonth,
        note: note,
        createdAt: now,
      );
      await transaction.insert(
        AppDatabase.goalTransactionsTable,
        goalTransaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return goalTransaction;
    });
  }

  Future<int> _currentBalance(DatabaseExecutor executor, String goalId) async {
    final List<Map<String, Object?>> rows = await executor.query(
      AppDatabase.goalTransactionsTable,
      columns: <String>['balanceAfterCents'],
      where: 'goalId = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'createdAt DESC, rowid DESC',
      limit: 1,
    );
    return (rows.firstOrNull?['balanceAfterCents'] as num?)?.toInt() ?? 0;
  }

  void _validateGoal(SavingsGoal goal) {
    if (goal.id.trim().isEmpty ||
        goal.name.trim().isEmpty ||
        goal.targetCents <= 0) {
      throw ArgumentError('Preencha o nome e informe um objetivo válido.');
    }
  }
}
