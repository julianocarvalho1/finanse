import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/evolution/data/financial_evolution_service.dart';
import 'package:finanse/features/evolution/domain/financial_evolution.dart';
import 'package:finanse/features/expenses/data/expense_repository.dart';
import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:finanse/features/incomes/data/income_repository.dart';
import 'package:finanse/features/incomes/domain/income.dart';
import 'package:finanse/features/goals/data/goal_repository.dart';
import 'package:finanse/features/goals/domain/savings_goal.dart';
import 'package:finanse/features/planning/data/monthly_plan_repository.dart';
import 'package:finanse/features/reserve/data/reserve_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late IncomeRepository incomeRepository;
  late MonthlyPlanRepository planRepository;
  late ExpenseRepository expenseRepository;
  late ReserveRepository reserveRepository;
  late GoalRepository goalRepository;
  late FinancialEvolutionService service;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createTables(database);
    incomeRepository = IncomeRepository(database: database);
    planRepository = MonthlyPlanRepository(database: database);
    expenseRepository = ExpenseRepository(database: database);
    reserveRepository = ReserveRepository(database: database);
    goalRepository = GoalRepository(database: database);
    service = FinancialEvolutionService(
      incomeRepository: incomeRepository,
      planRepository: planRepository,
      expenseRepository: expenseRepository,
      reserveRepository: reserveRepository,
      goalRepository: goalRepository,
    );
  });

  tearDown(() => database.close());

  test('monta meses em ordem e mantém resultado negativo', () async {
    await incomeRepository.insertIncome(
      _income(
        id: 'salary',
        cents: 500000,
        date: DateTime(2026, 7, 5),
        recurrence: IncomeRecurrence.monthly,
      ),
    );
    await planRepository.saveLimit(
      month: DateTime(2026, 7),
      spendingLimitCents: 200000,
    );
    await planRepository.saveLimit(
      month: DateTime(2026, 8),
      spendingLimitCents: 220000,
    );
    await expenseRepository.insertExpense(
      _expense(id: 'july', amount: 1800, date: DateTime(2026, 7, 10)),
    );
    await expenseRepository.insertExpense(
      _expense(id: 'august', amount: 5300, date: DateTime(2026, 8, 10)),
    );

    final FinancialEvolution evolution = await service.load(
      referenceMonth: DateTime(2026, 8, 31),
      monthCount: 2,
    );

    expect(
      evolution.months.map((MonthlyEvolutionSnapshot item) => item.yearMonth),
      <String>['2026-07', '2026-08'],
    );
    expect(evolution.months.first.resultCents, 320000);
    expect(evolution.months.last.resultCents, -30000);
    expect(evolution.months.last.spendingLimitCents, 220000);
  });

  test('recalcula uma correção retroativa sem duplicar o mês', () async {
    await incomeRepository.insertIncome(
      _income(id: 'income', cents: 500000, date: DateTime(2026, 7, 1)),
    );
    final Expense expense = _expense(
      id: 'expense',
      amount: 2000,
      date: DateTime(2026, 7, 10),
    );
    await expenseRepository.insertExpense(expense);

    FinancialEvolution evolution = await service.load(
      referenceMonth: DateTime(2026, 7),
      monthCount: 1,
    );
    expect(evolution.months.single.resultCents, 300000);

    await expenseRepository.updateExpense(
      expense.copyWith(amount: 2500, updatedAt: DateTime(2026, 7, 11)),
    );
    evolution = await service.load(
      referenceMonth: DateTime(2026, 7),
      monthCount: 1,
    );

    expect(evolution.months, hasLength(1));
    expect(evolution.months.single.spentCents, 250000);
    expect(evolution.months.single.resultCents, 250000);
  });

  test('considera reserva e metas vinculadas ao mês', () async {
    await incomeRepository.insertIncome(
      _income(id: 'income', cents: 500000, date: DateTime(2026, 8, 1)),
    );
    await reserveRepository.addAmount(1000, originYearMonth: '2026-08');
    await reserveRepository.addAmount(500, originYearMonth: '2026-07');
    final DateTime createdAt = DateTime(2026, 8, 1);
    await goalRepository.createGoal(
      SavingsGoal(
        id: 'goal',
        name: 'Curso',
        targetCents: 200000,
        status: SavingsGoalStatus.active,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    await goalRepository.allocate(
      goalId: 'goal',
      amountCents: 50000,
      originYearMonth: '2026-08',
    );

    final FinancialEvolution evolution = await service.load(
      referenceMonth: DateTime(2026, 8),
      monthCount: 1,
    );

    expect(evolution.months.single.allocatedToReserveCents, 100000);
    expect(evolution.months.single.allocatedToGoalsCents, 50000);
    expect(evolution.months.single.availableToReserveCents, 350000);
  });
}

Income _income({
  required String id,
  required int cents,
  required DateTime date,
  IncomeRecurrence recurrence = IncomeRecurrence.none,
}) {
  return Income(
    id: id,
    amountCents: cents,
    source: id,
    date: date,
    recurrence: recurrence,
    createdAt: date,
    updatedAt: date,
  );
}

Expense _expense({
  required String id,
  required double amount,
  required DateTime date,
}) {
  return Expense(
    id: id,
    amount: amount,
    categoryName: 'Outros',
    date: date,
    createdAt: date,
    updatedAt: date,
  );
}

Future<void> _createTables(Database database) async {
  await database.execute('''
    CREATE TABLE ${AppDatabase.expensesTable} (
      id TEXT PRIMARY KEY,
      amount REAL NOT NULL,
      categoryName TEXT NOT NULL,
      description TEXT,
      notes TEXT,
      date TEXT NOT NULL,
      paymentMethod TEXT,
      isRecurring INTEGER NOT NULL DEFAULT 0,
      recurringExpenseId TEXT,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppDatabase.incomesTable} (
      id TEXT PRIMARY KEY,
      amountCents INTEGER NOT NULL,
      source TEXT NOT NULL,
      date TEXT NOT NULL,
      recurrence TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppDatabase.monthlyPlansTable} (
      yearMonth TEXT PRIMARY KEY,
      spendingLimitCents INTEGER NOT NULL,
      warningPercent INTEGER NOT NULL DEFAULT 70,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppDatabase.reserveTransactionsTable} (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      previousBalance REAL NOT NULL,
      balanceAfter REAL NOT NULL,
      note TEXT,
      originYearMonth TEXT,
      createdAt TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppDatabase.savingsGoalsTable} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      targetCents INTEGER NOT NULL,
      deadline TEXT,
      status TEXT NOT NULL,
      completedAt TEXT,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppDatabase.goalTransactionsTable} (
      id TEXT PRIMARY KEY,
      goalId TEXT NOT NULL,
      type TEXT NOT NULL,
      changeCents INTEGER NOT NULL,
      balanceAfterCents INTEGER NOT NULL,
      originYearMonth TEXT,
      note TEXT,
      createdAt TEXT NOT NULL
    )
  ''');
}
