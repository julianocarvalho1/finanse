import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/category_limits/data/category_limit_repository.dart';
import 'package:finanse/features/category_limits/domain/category_limit.dart';
import 'package:finanse/features/evolution/data/financial_evolution_service.dart';
import 'package:finanse/features/evolution/domain/financial_evolution.dart';
import 'package:finanse/features/expenses/data/expense_repository.dart';
import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:finanse/features/goals/data/goal_repository.dart';
import 'package:finanse/features/goals/domain/goal_progress.dart';
import 'package:finanse/features/goals/domain/savings_goal.dart';
import 'package:finanse/features/incomes/data/income_repository.dart';
import 'package:finanse/features/incomes/domain/income.dart';
import 'package:finanse/features/planning/data/monthly_plan_repository.dart';
import 'package:finanse/features/planning/domain/monthly_financial_summary.dart';
import 'package:finanse/features/reserve/data/reserve_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late IncomeRepository incomeRepository;
  late ExpenseRepository expenseRepository;
  late MonthlyPlanRepository planRepository;
  late CategoryLimitRepository categoryLimitRepository;
  late GoalRepository goalRepository;
  late ReserveRepository reserveRepository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createTables(database);
    incomeRepository = IncomeRepository(database: database);
    expenseRepository = ExpenseRepository(database: database);
    planRepository = MonthlyPlanRepository(database: database);
    categoryLimitRepository = CategoryLimitRepository(database: database);
    goalRepository = GoalRepository(database: database);
    reserveRepository = ReserveRepository(database: database);
  });

  tearDown(() => database.close());

  test(
    'mantém coerente renda de 5 mil, limite de 2 mil, categorias e metas',
    () async {
      final DateTime month = DateTime(2026, 8);
      final DateTime createdAt = DateTime(2026, 8, 1, 8);

      await incomeRepository.insertIncome(
        Income(
          id: 'salary',
          amountCents: 500000,
          source: 'Salário',
          date: DateTime(2026, 8, 5),
          recurrence: IncomeRecurrence.monthly,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      final plan = await planRepository.saveLimit(
        month: month,
        spendingLimitCents: 200000,
        warningPercent: 70,
      );

      await categoryLimitRepository.saveLimit(
        month: month,
        categoryName: 'Alimentação',
        limitCents: 80000,
        warningPercent: 75,
      );
      await categoryLimitRepository.saveLimit(
        month: month,
        categoryName: 'Transporte',
        limitCents: 40000,
        warningPercent: 70,
      );
      await categoryLimitRepository.saveLimit(
        month: month,
        categoryName: 'Moradia',
        limitCents: 80000,
        warningPercent: 80,
      );

      await expenseRepository.insertExpense(
        _expense(
          id: 'previous-food',
          amount: 700,
          category: 'Alimentação',
          date: DateTime(2026, 7, 12),
        ),
      );
      await expenseRepository.insertExpense(
        _expense(
          id: 'food',
          amount: 500,
          category: 'Alimentação',
          date: DateTime(2026, 8, 10),
        ),
      );
      await expenseRepository.insertExpense(
        _expense(
          id: 'transport',
          amount: 300,
          category: 'Transporte',
          date: DateTime(2026, 8, 11),
        ),
      );
      await expenseRepository.insertExpense(
        _expense(
          id: 'housing',
          amount: 600,
          category: 'Moradia',
          date: DateTime(2026, 8, 12),
        ),
      );

      final int incomeCents = await incomeRepository.getTotalCentsForMonth(
        month,
      );
      final int spentCents =
          (await expenseRepository.getTotalBetween(
                    start: month,
                    endExclusive: DateTime(2026, 9),
                  ) *
                  100)
              .round();
      final MonthlyFinancialSummary summary = MonthlyFinancialSummary(
        incomeTotalCents: incomeCents,
        spendingLimitCents: plan.spendingLimitCents,
        spentCents: spentCents,
        warningPercent: plan.warningPercent,
      );

      expect(incomeCents, 500000);
      expect(spentCents, 140000);
      expect(summary.plannedSurplusCents, 300000);
      expect(summary.currentResultCents, 360000);
      expect(summary.availableWithinLimitCents, 60000);
      expect(summary.status, MonthlyFinancialStatus.attention);

      final List<CategoryLimitSummary> categorySummaries =
          await categoryLimitRepository.getSummariesForMonth(month);
      final Map<String, CategoryLimitSummary> byCategory =
          <String, CategoryLimitSummary>{
            for (final CategoryLimitSummary item in categorySummaries)
              item.categoryName: item,
          };
      expect(
        byCategory['Alimentação']!.status,
        CategoryLimitStatus.comfortable,
      );
      expect(byCategory['Alimentação']!.differenceCents, -20000);
      expect(byCategory['Transporte']!.status, CategoryLimitStatus.attention);
      expect(byCategory['Moradia']!.status, CategoryLimitStatus.comfortable);

      await expectLater(
        categoryLimitRepository.saveLimit(
          month: month,
          categoryName: 'Lazer',
          limitCents: 1,
          warningPercent: 70,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        planRepository.saveLimit(month: month, spendingLimitCents: 199999),
        throwsA(isA<StateError>()),
      );

      await goalRepository.createGoal(
        SavingsGoal(
          id: 'trip',
          name: 'Viagem',
          targetCents: 1000000,
          deadline: DateTime(2027, 12, 31),
          status: SavingsGoalStatus.active,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await goalRepository.createGoal(
        SavingsGoal(
          id: 'course',
          name: 'Curso',
          targetCents: 300000,
          status: SavingsGoalStatus.active,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await goalRepository.allocate(
        goalId: 'trip',
        amountCents: 100000,
        originYearMonth: '2026-08',
      );
      await goalRepository.allocate(
        goalId: 'course',
        amountCents: 50000,
        originYearMonth: '2026-08',
      );
      await reserveRepository.addAmount(700, originYearMonth: '2026-08');

      final Map<String, GoalProgress> goals = <String, GoalProgress>{
        for (final GoalProgress item
            in await goalRepository.getGoalsWithProgress())
          item.goal.id: item,
      };
      expect(goals['trip']!.savedCents, 100000);
      expect(goals['trip']!.progress, 0.1);
      expect(goals['course']!.savedCents, 50000);
      expect(goals['course']!.progress, closeTo(1 / 6, 0.0001));

      final FinancialEvolution evolution = await FinancialEvolutionService(
        incomeRepository: incomeRepository,
        planRepository: planRepository,
        expenseRepository: expenseRepository,
        reserveRepository: reserveRepository,
        goalRepository: goalRepository,
      ).load(referenceMonth: month, monthCount: 1);
      final MonthlyEvolutionSnapshot snapshot = evolution.months.single;
      expect(snapshot.allocatedToGoalsCents, 150000);
      expect(snapshot.allocatedToReserveCents, 70000);
      expect(snapshot.availableToReserveCents, 140000);

      final int spentAfterAllocations =
          (await expenseRepository.getTotalBetween(
                    start: month,
                    endExclusive: DateTime(2026, 9),
                  ) *
                  100)
              .round();
      expect(spentAfterAllocations, 140000);
      expect(await database.query(AppDatabase.expensesTable), hasLength(4));
    },
  );
}

Expense _expense({
  required String id,
  required double amount,
  required String category,
  required DateTime date,
}) {
  return Expense(
    id: id,
    amount: amount,
    categoryName: category,
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
      warningPercent INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppDatabase.categoryLimitsTable} (
      yearMonth TEXT NOT NULL,
      categoryName TEXT NOT NULL,
      limitCents INTEGER NOT NULL,
      warningPercent INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      PRIMARY KEY(yearMonth, categoryName)
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
}
