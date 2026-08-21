import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/income.dart';

class IncomeRepository {
  IncomeRepository({AppDatabase? appDatabase, Database? database})
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

  Future<void> insertIncome(Income income) async {
    _validate(income);
    final Database database = await _database;
    await database.insert(
      AppDatabase.incomesTable,
      income.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateIncome(Income income) async {
    _validate(income);
    final Database database = await _database;
    final int changed = await database.update(
      AppDatabase.incomesTable,
      income.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[income.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    if (changed == 0) {
      throw StateError('A renda não foi encontrada.');
    }
  }

  Future<void> deleteIncome(String id) async {
    final Database database = await _database;
    final int changed = await database.delete(
      AppDatabase.incomesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    if (changed == 0) {
      throw StateError('A renda não foi encontrada.');
    }
  }

  Future<List<Income>> getIncomesForMonth(DateTime month) async {
    final Database database = await _database;
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);

    final List<Map<String, Object?>> rows = await database.query(
      AppDatabase.incomesTable,
      where: '''
        (recurrence = 'none' AND date >= ? AND date < ?)
        OR (recurrence = 'monthly' AND date < ?)
      ''',
      whereArgs: <Object?>[
        start.toIso8601String(),
        end.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC, createdAt DESC',
    );

    return rows.map<Income>(Income.fromMap).toList(growable: false);
  }

  Future<int> getTotalCentsForMonth(DateTime month) async {
    final List<Income> incomes = await getIncomesForMonth(month);
    return incomes.fold<int>(
      0,
      (int total, Income income) => total + income.amountCents,
    );
  }

  void _validate(Income income) {
    if (income.id.trim().isEmpty ||
        income.source.trim().isEmpty ||
        income.amountCents <= 0) {
      throw ArgumentError('Preencha a fonte e informe um valor válido.');
    }
  }
}
