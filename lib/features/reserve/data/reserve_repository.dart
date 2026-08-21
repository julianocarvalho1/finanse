import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/reserve_transaction.dart';

class ReserveRepository {
  ReserveRepository({AppDatabase? appDatabase, Database? database})
    : assert(
        appDatabase == null || database == null,
        'Informe AppDatabase ou Database, não os dois.',
      ),
      _appDatabase = appDatabase ?? AppDatabase.instance,
      _injectedDatabase = database,
      _uuid = const Uuid();

  final AppDatabase _appDatabase;
  final Database? _injectedDatabase;
  final Uuid _uuid;

  Future<Database> get _database async {
    return _injectedDatabase ?? _appDatabase.database;
  }

  Future<List<ReserveTransaction>> getTransactions() async {
    final Database database = await _database;

    final List<Map<String, Object?>> rows = await database.query(
      AppDatabase.reserveTransactionsTable,
      orderBy: 'createdAt DESC, rowid DESC',
    );

    return rows
        .map<ReserveTransaction>(ReserveTransaction.fromMap)
        .toList(growable: false);
  }

  Future<double> getCurrentBalance() async {
    final Database database = await _database;
    return _currentBalance(database);
  }

  Future<bool> hasTransactions() async {
    final Database database = await _database;

    final int? count = Sqflite.firstIntValue(
      await database.rawQuery(
        'SELECT COUNT(*) FROM ${AppDatabase.reserveTransactionsTable}',
      ),
    );

    return (count ?? 0) > 0;
  }

  Future<ReserveTransaction?> migrateLegacyBalance(double balance) async {
    if (balance <= 0 || await hasTransactions()) {
      return null;
    }

    return adjustBalance(
      balance,
      note: 'Saldo existente antes do histórico da reserva.',
    );
  }

  Future<ReserveTransaction> addAmount(
    double amount, {
    String? note,
    String? originYearMonth,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Use um valor maior que zero.',
      );
    }

    return _insertChange(
      type: ReserveTransactionType.add,
      amount: amount,
      note: note,
      originYearMonth: originYearMonth,
      balanceBuilder: (double currentBalance) => currentBalance + amount,
    );
  }

  Future<ReserveTransaction> withdrawAmount(
    double amount, {
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Use um valor maior que zero.',
      );
    }

    return _insertChange(
      type: ReserveTransactionType.withdraw,
      amount: amount,
      note: note,
      balanceBuilder: (double currentBalance) {
        if (amount > currentBalance) {
          throw StateError('O valor informado é maior que a reserva atual.');
        }

        return currentBalance - amount;
      },
    );
  }

  Future<ReserveTransaction> adjustBalance(
    double newBalance, {
    String? note,
  }) async {
    if (newBalance < 0) {
      throw ArgumentError.value(
        newBalance,
        'newBalance',
        'A reserva não pode ser negativa.',
      );
    }

    return _insertChange(
      type: ReserveTransactionType.adjust,
      amount: 0,
      note: note,
      balanceBuilder: (_) => newBalance,
    );
  }

  Future<ReserveTransaction> _insertChange({
    required ReserveTransactionType type,
    required double amount,
    required double Function(double currentBalance) balanceBuilder,
    String? note,
    String? originYearMonth,
  }) async {
    final Database database = await _database;

    return database.transaction<ReserveTransaction>((
      Transaction transaction,
    ) async {
      final double previousBalance = await _currentBalance(transaction);
      final double balanceAfter = _roundCurrency(
        balanceBuilder(previousBalance),
      );
      final DateTime now = DateTime.now();
      final String normalizedNote = note?.trim() ?? '';

      final ReserveTransaction reserveTransaction = ReserveTransaction(
        id: _uuid.v4(),
        type: type,
        amount: type == ReserveTransactionType.adjust
            ? (balanceAfter - previousBalance).abs()
            : amount,
        previousBalance: previousBalance,
        balanceAfter: balanceAfter,
        note: normalizedNote.isEmpty ? null : normalizedNote,
        originYearMonth: originYearMonth,
        createdAt: now,
      );

      await transaction.insert(
        AppDatabase.reserveTransactionsTable,
        reserveTransaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return reserveTransaction;
    });
  }

  Future<int> getAllocatedCentsForMonth(String yearMonth) async {
    final Database database = await _database;
    final List<Map<String, Object?>> result = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM ${AppDatabase.reserveTransactionsTable}
      WHERE type = 'add' AND originYearMonth = ?
      ''',
      <Object?>[yearMonth],
    );

    final Object? value = result.firstOrNull?['total'];
    return value is num ? (value.toDouble() * 100).round() : 0;
  }

  double _roundCurrency(double value) {
    return (value * 100).round() / 100;
  }

  Future<double> _currentBalance(DatabaseExecutor executor) async {
    final List<Map<String, Object?>> rows = await executor.query(
      AppDatabase.reserveTransactionsTable,
      columns: <String>['balanceAfter'],
      orderBy: 'createdAt DESC, rowid DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return 0;
    }

    return (rows.first['balanceAfter']! as num).toDouble();
  }
}
