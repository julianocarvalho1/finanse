import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../domain/expense.dart';

class ExpenseRepository {
  final AppDatabase _appDatabase = AppDatabase.instance;

  // 1. Salva a despesa no banco
  Future<void> insertExpense(Expense expense) async {
    final db = await _appDatabase.database;

    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 2. Busca apenas as despesas cadastradas no dia de hoje
  Future<List<Expense>> getTodayExpenses() async {
    final db = await _appDatabase.database;

    // Pega o início e o fim do dia de hoje para filtrar
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    // Faz a consulta no banco de dados ordenando do mais recente para o mais antigo
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [todayStart, todayEnd],
      orderBy: 'date DESC',
    );

    // Transforma a resposta do banco de volta na nossa classe Expense
    return List.generate(maps.length, (i) {
      return Expense.fromMap(maps[i]);
    });
  }

  // 3. Calcula o valor total gasto hoje
  Future<double> getTodayTotal() async {
    final expenses = await getTodayExpenses();
    double total = 0;

    for (var expense in expenses) {
      total += expense.amount;
    }

    return total;
  }

  // 4. Busca TODAS as despesas cadastradas na história do app
  Future<List<Expense>> getAllExpenses() async {
    final db = await _appDatabase.database;

    // Busca tudo, ordenando da data mais recente para a mais antiga
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Expense.fromMap(maps[i]);
    });
  }

  // 5. Apaga uma despesa específica usando o ID dela
  Future<void> deleteExpense(String id) async {
    final db = await _appDatabase.database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- NOVA FUNÇÃO PARA A ETAPA 3 ---
  // Busca os gastos e filtra pelo período escolhido
  Future<List<Expense>> getExpensesForPeriod(String period) async {
    final db = await _appDatabase.database; // <-- CORRIGIDO AQUI!
    // Pega todos os gastos ordenados do mais novo para o mais velho
    final List<Map<String, dynamic>> maps = await db.query('expenses', orderBy: 'date DESC');

    final allExpenses = maps.map((map) => Expense.fromMap(map)).toList();
    final now = DateTime.now();

    return allExpenses.where((e) {
      if (period == 'Hoje') {
        return e.date.year == now.year && e.date.month == now.month && e.date.day == now.day;
      } else if (period == 'Semana') {
        // Últimos 7 dias
        final weekAgo = now.subtract(const Duration(days: 7));
        return e.date.isAfter(weekAgo) || (e.date.year == now.year && e.date.month == now.month && e.date.day == now.day);
      } else if (period == 'Mês') {
        return e.date.year == now.year && e.date.month == now.month;
      }
      return true;
    }).toList();
  }
}