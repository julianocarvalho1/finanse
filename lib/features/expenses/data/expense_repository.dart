import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../domain/expense.dart';

/// Responsável por todas as operações relacionadas às despesas no SQLite.
///
/// As telas não devem acessar o banco diretamente. Toda inclusão, edição,
/// exclusão ou consulta de despesas deve passar por este repositório.
class ExpenseRepository {
  ExpenseRepository({
    AppDatabase? appDatabase,
  }) : _appDatabase = appDatabase ?? AppDatabase.instance;

  static const String _tableName = 'expenses';

  final AppDatabase _appDatabase;

  Future<Database> get _database async {
    return _appDatabase.database;
  }

  /// Insere uma nova despesa.
  ///
  /// Caso já exista uma despesa com o mesmo ID, uma exceção será lançada
  /// em vez de substituir silenciosamente o registro existente.
  Future<void> insertExpense(Expense expense) async {
    final Database db = await _database;

    await db.insert(
      _tableName,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Atualiza uma despesa existente de forma segura.
  ///
  /// Diferentemente da estratégia de excluir e inserir novamente, este método
  /// mantém o registro original no banco caso a atualização falhe.
  Future<void> updateExpense(Expense expense) async {
    final Database db = await _database;

    final int affectedRows = await db.update(
      _tableName,
      expense.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[
        expense.id,
      ],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    if (affectedRows == 0) {
      throw StateError(
        'Não foi possível atualizar o gasto porque ele não foi encontrado.',
      );
    }
  }

  /// Insere ou atualiza uma despesa dentro de uma transação.
  ///
  /// Este método será útil em restaurações de backup e sincronizações futuras.
  Future<void> saveExpense(Expense expense) async {
    final Database db = await _database;

    await db.transaction(
          (Transaction transaction) async {
        final List<Map<String, Object?>> existingRows =
        await transaction.query(
          _tableName,
          columns: <String>[
            'id',
          ],
          where: 'id = ?',
          whereArgs: <Object?>[
            expense.id,
          ],
          limit: 1,
        );

        if (existingRows.isEmpty) {
          await transaction.insert(
            _tableName,
            expense.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          return;
        }

        final int affectedRows = await transaction.update(
          _tableName,
          expense.toMap(),
          where: 'id = ?',
          whereArgs: <Object?>[
            expense.id,
          ],
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        if (affectedRows == 0) {
          throw StateError(
            'Não foi possível salvar as alterações do gasto.',
          );
        }
      },
    );
  }

  /// Busca uma despesa específica pelo ID.
  Future<Expense?> getExpenseById(String id) async {
    final Database db = await _database;

    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[
        id,
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Expense.fromMap(rows.first);
  }

  /// Retorna todas as despesas registradas no dia atual.
  Future<List<Expense>> getTodayExpenses() async {
    final DateTime now = DateTime.now();
    final DateTime start = _startOfDay(now);
    final DateTime end = start.add(
      const Duration(days: 1),
    );

    return getExpensesBetween(
      start: start,
      endExclusive: end,
    );
  }

  /// Retorna o total gasto no dia atual.
  Future<double> getTodayTotal() async {
    final DateTime now = DateTime.now();
    final DateTime start = _startOfDay(now);
    final DateTime end = start.add(
      const Duration(days: 1),
    );

    return getTotalBetween(
      start: start,
      endExclusive: end,
    );
  }

  /// Retorna todas as despesas, da mais recente para a mais antiga.
  Future<List<Expense>> getAllExpenses() async {
    final Database db = await _database;

    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      orderBy: 'date DESC',
    );

    return rows
        .map(
          (Map<String, Object?> row) => Expense.fromMap(row),
    )
        .toList(growable: false);
  }

  /// Retorna despesas conforme o seletor usado na tela inicial.
  ///
  /// Períodos reconhecidos:
  /// - Hoje
  /// - Semana
  /// - Mês
  ///
  /// Qualquer outro valor retorna todas as despesas.
  Future<List<Expense>> getExpensesForPeriod(String period) async {
    final DateTime now = DateTime.now();

    switch (period.trim().toLowerCase()) {
      case 'hoje':
        final DateTime start = _startOfDay(now);
        final DateTime end = start.add(
          const Duration(days: 1),
        );

        return getExpensesBetween(
          start: start,
          endExclusive: end,
        );

      case 'semana':
      // Hoje mais os seis dias anteriores.
        final DateTime start = _startOfDay(
          now.subtract(
            const Duration(days: 6),
          ),
        );

        final DateTime end = _startOfDay(now).add(
          const Duration(days: 1),
        );

        return getExpensesBetween(
          start: start,
          endExclusive: end,
        );

      case 'mês':
      case 'mes':
        final DateTime start = DateTime(
          now.year,
          now.month,
        );

        final DateTime end = DateTime(
          now.year,
          now.month + 1,
        );

        return getExpensesBetween(
          start: start,
          endExclusive: end,
        );

      default:
        return getAllExpenses();
    }
  }

  /// Retorna despesas dentro de um intervalo.
  ///
  /// A data inicial é inclusiva e a data final é exclusiva:
  ///
  /// start <= data < endExclusive
  Future<List<Expense>> getExpensesBetween({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    _validateDateRange(
      start: start,
      endExclusive: endExclusive,
    );

    final Database db = await _database;

    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      where: 'date >= ? AND date < ?',
      whereArgs: <Object?>[
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );

    return rows
        .map(
          (Map<String, Object?> row) => Expense.fromMap(row),
    )
        .toList(growable: false);
  }

  /// Calcula o total gasto dentro de um intervalo.
  Future<double> getTotalBetween({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    _validateDateRange(
      start: start,
      endExclusive: endExclusive,
    );

    final Database db = await _database;

    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM $_tableName
      WHERE date >= ? AND date < ?
      ''',
      <Object?>[
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
    );

    if (result.isEmpty) {
      return 0;
    }

    final Object? totalValue = result.first['total'];

    if (totalValue is num) {
      return totalValue.toDouble();
    }

    return double.tryParse(
      totalValue?.toString() ?? '',
    ) ??
        0;
  }

  /// Exclui uma despesa pelo ID.
  Future<void> deleteExpense(String id) async {
    final Database db = await _database;

    final int affectedRows = await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );

    if (affectedRows == 0) {
      throw StateError(
        'Não foi possível excluir o gasto porque ele não foi encontrado.',
      );
    }
  }

  /// Exclui uma despesa e devolve uma cópia do registro removido.
  ///
  /// Será utilizado para implementar a ação "Desfazer".
  Future<Expense> deleteExpenseAndReturn(String id) async {
    final Database db = await _database;

    return db.transaction(
          (Transaction transaction) async {
        final List<Map<String, Object?>> rows = await transaction.query(
          _tableName,
          where: 'id = ?',
          whereArgs: <Object?>[
            id,
          ],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw StateError(
            'Não foi possível excluir o gasto porque ele não foi encontrado.',
          );
        }

        final Expense expense = Expense.fromMap(
          rows.first,
        );

        final int affectedRows = await transaction.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: <Object?>[
            id,
          ],
        );

        if (affectedRows == 0) {
          throw StateError(
            'Não foi possível excluir o gasto.',
          );
        }

        return expense;
      },
    );
  }

  /// Verifica se já existe um gasto muito parecido registrado recentemente.
  ///
  /// Essa consulta será usada depois para alertar sobre possíveis duplicidades,
  /// sem impedir o salvamento.
  Future<bool> hasSimilarRecentExpense({
    required double amount,
    required String categoryName,
    Duration interval = const Duration(minutes: 2),
  }) async {
    final Database db = await _database;
    final DateTime minimumDate = DateTime.now().subtract(interval);

    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      columns: <String>[
        'id',
      ],
      where: '''
        amount = ?
        AND categoryName = ?
        AND createdAt >= ?
      ''',
      whereArgs: <Object?>[
        amount,
        categoryName,
        minimumDate.toIso8601String(),
      ],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  static void _validateDateRange({
    required DateTime start,
    required DateTime endExclusive,
  }) {
    if (!endExclusive.isAfter(start)) {
      throw ArgumentError(
        'A data final precisa ser posterior à data inicial.',
      );
    }
  }
}