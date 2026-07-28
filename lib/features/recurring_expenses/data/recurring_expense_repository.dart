import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../expenses/domain/expense.dart';
import '../domain/recurring_expense.dart';

/// Resultado de uma recorrência marcada como registrada.
///
/// Mantém o estado anterior para permitir a ação "Desfazer".
class RecurringRegistrationResult {
  const RecurringRegistrationResult({
    required this.expense,
    required this.previousRecurringExpense,
    required this.updatedRecurringExpense,
  });

  /// Gasto criado no histórico.
  final Expense expense;

  /// Estado da recorrência antes do registro.
  final RecurringExpense previousRecurringExpense;

  /// Estado da recorrência após avançar a próxima data.
  final RecurringExpense updatedRecurringExpense;
}

/// Responsável pelas operações de despesas recorrentes no SQLite.
///
/// A criação do gasto no histórico e o avanço da recorrência acontecem
/// dentro da mesma transação. Dessa forma, o aplicativo não cria o gasto
/// sem atualizar a recorrência, nem atualiza a recorrência sem criar o gasto.
class RecurringExpenseRepository {
  RecurringExpenseRepository({AppDatabase? appDatabase, Database? database})
    : assert(
        appDatabase == null || database == null,
        'Informe AppDatabase ou Database, não os dois.',
      ),
      _appDatabase = appDatabase ?? AppDatabase.instance,
      _injectedDatabase = database;

  final AppDatabase _appDatabase;
  final Database? _injectedDatabase;

  Future<Database> get _database async {
    final Database? injectedDatabase = _injectedDatabase;

    if (injectedDatabase != null) {
      return injectedDatabase;
    }

    return _appDatabase.database;
  }

  /// Cria uma nova despesa recorrente.
  Future<void> insertRecurringExpense(RecurringExpense recurringExpense) async {
    final Database db = await _database;

    await db.insert(
      AppDatabase.recurringExpensesTable,
      recurringExpense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Atualiza uma despesa recorrente existente.
  Future<void> updateRecurringExpense(RecurringExpense recurringExpense) async {
    final Database db = await _database;

    final int affectedRows = await db.update(
      AppDatabase.recurringExpensesTable,
      recurringExpense.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[recurringExpense.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    if (affectedRows == 0) {
      throw StateError('A despesa recorrente não foi encontrada.');
    }
  }

  /// Cria ou atualiza uma recorrência conforme o ID.
  ///
  /// Será útil para desfazer exclusões e restaurar backups.
  Future<void> saveRecurringExpense(RecurringExpense recurringExpense) async {
    final Database db = await _database;

    await db.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> existingRows = await transaction.query(
        AppDatabase.recurringExpensesTable,
        columns: <String>['id'],
        where: 'id = ?',
        whereArgs: <Object?>[recurringExpense.id],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        await transaction.insert(
          AppDatabase.recurringExpensesTable,
          recurringExpense.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        return;
      }

      final int affectedRows = await transaction.update(
        AppDatabase.recurringExpensesTable,
        recurringExpense.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[recurringExpense.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (affectedRows == 0) {
        throw StateError('Não foi possível salvar a despesa recorrente.');
      }
    });
  }

  /// Busca uma recorrência pelo ID.
  Future<RecurringExpense?> getRecurringExpenseById(String id) async {
    final Database db = await _database;

    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.recurringExpensesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return RecurringExpense.fromMap(rows.first);
  }

  /// Retorna todas as despesas recorrentes.
  ///
  /// As recorrências ativas aparecem primeiro. Dentro de cada grupo,
  /// a ordenação considera a próxima data.
  Future<List<RecurringExpense>> getAllRecurringExpenses({
    bool includePaused = true,
  }) async {
    final Database db = await _database;

    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.recurringExpensesTable,
      where: includePaused ? null : 'isActive = ?',
      whereArgs: includePaused ? null : <Object?>[1],
      orderBy: 'isActive DESC, nextDate ASC, createdAt DESC',
    );

    return rows
        .map((Map<String, Object?> row) {
          return RecurringExpense.fromMap(row);
        })
        .toList(growable: false);
  }

  /// Retorna somente as recorrências ativas.
  Future<List<RecurringExpense>> getActiveRecurringExpenses() {
    return getAllRecurringExpenses(includePaused: false);
  }

  /// Retorna recorrências ativas cuja próxima data já chegou.
  Future<List<RecurringExpense>> getDueRecurringExpenses({
    DateTime? referenceDate,
  }) async {
    final Database db = await _database;

    final DateTime effectiveReferenceDate = referenceDate ?? DateTime.now();

    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.recurringExpensesTable,
      where: 'isActive = ? AND nextDate <= ?',
      whereArgs: <Object?>[1, effectiveReferenceDate.toIso8601String()],
      orderBy: 'nextDate ASC',
    );

    return rows
        .map((Map<String, Object?> row) {
          return RecurringExpense.fromMap(row);
        })
        .toList(growable: false);
  }

  /// Retorna a quantidade de recorrências pendentes.
  Future<int> getDueRecurringExpenseCount({DateTime? referenceDate}) async {
    final Database db = await _database;

    final DateTime effectiveReferenceDate = referenceDate ?? DateTime.now();

    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${AppDatabase.recurringExpensesTable}
      WHERE isActive = ?
        AND nextDate <= ?
      ''',
      <Object?>[1, effectiveReferenceDate.toIso8601String()],
    );

    if (result.isEmpty) {
      return 0;
    }

    final Object? total = result.first['total'];

    if (total is num) {
      return total.toInt();
    }

    return int.tryParse(total?.toString() ?? '') ?? 0;
  }

  /// Pausa ou reativa uma recorrência.
  Future<RecurringExpense> setRecurringExpenseActive({
    required String id,
    required bool isActive,
  }) async {
    final Database db = await _database;

    return db.transaction((Transaction transaction) async {
      final RecurringExpense current =
          await _getRecurringExpenseInsideTransaction(
            transaction: transaction,
            id: id,
          );

      final RecurringExpense updated = current.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      final int affectedRows = await transaction.update(
        AppDatabase.recurringExpensesTable,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (affectedRows == 0) {
        throw StateError('Não foi possível alterar o estado da recorrência.');
      }

      return updated;
    });
  }

  /// Exclui uma recorrência.
  ///
  /// Os gastos que já foram criados por ela permanecem no histórico.
  Future<void> deleteRecurringExpense(String id) async {
    final Database db = await _database;

    final int affectedRows = await db.delete(
      AppDatabase.recurringExpensesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    if (affectedRows == 0) {
      throw StateError('A despesa recorrente não foi encontrada.');
    }
  }

  /// Exclui uma recorrência e devolve uma cópia para permitir "Desfazer".
  Future<RecurringExpense> deleteRecurringExpenseAndReturn(String id) async {
    final Database db = await _database;

    return db.transaction((Transaction transaction) async {
      final RecurringExpense recurringExpense =
          await _getRecurringExpenseInsideTransaction(
            transaction: transaction,
            id: id,
          );

      final int affectedRows = await transaction.delete(
        AppDatabase.recurringExpensesTable,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      if (affectedRows == 0) {
        throw StateError('Não foi possível excluir a despesa recorrente.');
      }

      return recurringExpense;
    });
  }

  /// Marca a recorrência como registrada.
  ///
  /// Esta operação:
  ///
  /// 1. Cria um gasto real no histórico.
  /// 2. Liga esse gasto à recorrência.
  /// 3. Atualiza a data do último registro.
  /// 4. Incrementa a quantidade de registros.
  /// 5. Avança a próxima data.
  ///
  /// Tudo acontece dentro de uma única transação.
  Future<RecurringRegistrationResult> registerRecurringExpense({
    required String recurringExpenseId,
    DateTime? registeredAt,
    DateTime? expenseDate,
  }) async {
    final Database db = await _database;

    final DateTime effectiveRegisteredAt = registeredAt ?? DateTime.now();

    return db.transaction((Transaction transaction) async {
      final RecurringExpense recurringExpense =
          await _getRecurringExpenseInsideTransaction(
            transaction: transaction,
            id: recurringExpenseId,
          );

      if (!recurringExpense.isActive) {
        throw StateError('A despesa recorrente está pausada.');
      }

      final DateTime effectiveExpenseDate =
          expenseDate ?? effectiveRegisteredAt;

      final String expenseId =
          '${recurringExpense.id}_'
          '${effectiveRegisteredAt.microsecondsSinceEpoch}';

      final Expense expense = Expense(
        id: expenseId,
        amount: recurringExpense.amount,
        categoryName: recurringExpense.categoryName,
        description: recurringExpense.description,
        notes: recurringExpense.notes,
        date: effectiveExpenseDate,
        paymentMethod: recurringExpense.paymentMethod,
        isRecurring: true,
        createdAt: effectiveRegisteredAt,
        updatedAt: effectiveRegisteredAt,
      );

      final Map<String, Object?> expenseMap = expense.toMap();

      expenseMap['recurringExpenseId'] = recurringExpense.id;

      await transaction.insert(
        AppDatabase.expensesTable,
        expenseMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final RecurringExpense updatedRecurringExpense = recurringExpense
          .markAsRegistered(registeredAt: effectiveRegisteredAt);

      final int affectedRows = await transaction.update(
        AppDatabase.recurringExpensesTable,
        updatedRecurringExpense.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[recurringExpense.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (affectedRows == 0) {
        throw StateError('Não foi possível atualizar a próxima data.');
      }

      return RecurringRegistrationResult(
        expense: expense,
        previousRecurringExpense: recurringExpense,
        updatedRecurringExpense: updatedRecurringExpense,
      );
    });
  }

  /// Desfaz um registro realizado por uma recorrência.
  ///
  /// Remove o gasto criado e restaura a recorrência ao estado anterior.
  Future<void> undoRegistration(RecurringRegistrationResult result) async {
    final Database db = await _database;

    await db.transaction((Transaction transaction) async {
      final int deletedExpenses = await transaction.delete(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: <Object?>[result.expense.id],
      );

      if (deletedExpenses == 0) {
        throw StateError('O gasto criado pela recorrência não foi encontrado.');
      }

      final int restoredRecurringExpenses = await transaction.update(
        AppDatabase.recurringExpensesTable,
        result.previousRecurringExpense.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[result.previousRecurringExpense.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (restoredRecurringExpenses == 0) {
        throw StateError('Não foi possível restaurar a recorrência.');
      }
    });
  }

  Future<RecurringExpense> _getRecurringExpenseInsideTransaction({
    required Transaction transaction,
    required String id,
  }) async {
    final List<Map<String, Object?>> rows = await transaction.query(
      AppDatabase.recurringExpensesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('A despesa recorrente não foi encontrada.');
    }

    return RecurringExpense.fromMap(rows.first);
  }
}
