import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/goals/data/goal_repository.dart';
import 'package:finanse/features/goals/domain/goal_progress.dart';
import 'package:finanse/features/goals/domain/goal_transaction.dart';
import 'package:finanse/features/goals/domain/savings_goal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GoalRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await database.execute('''
      CREATE TABLE ${AppDatabase.savingsGoalsTable} (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, targetCents INTEGER NOT NULL,
        deadline TEXT, status TEXT NOT NULL, completedAt TEXT,
        createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppDatabase.goalTransactionsTable} (
        id TEXT PRIMARY KEY, goalId TEXT NOT NULL, type TEXT NOT NULL,
        changeCents INTEGER NOT NULL, balanceAfterCents INTEGER NOT NULL,
        originYearMonth TEXT, note TEXT, createdAt TEXT NOT NULL,
        FOREIGN KEY(goalId) REFERENCES ${AppDatabase.savingsGoalsTable}(id)
      )
    ''');
    repository = GoalRepository(database: database);
  });

  tearDown(() => database.close());

  test('acompanha progresso sem criar despesas', () async {
    await repository.createGoal(_goal());
    await repository.allocate(
      goalId: 'goal',
      amountCents: 120000,
      originYearMonth: '2026-08',
    );
    await repository.allocate(goalId: 'goal', amountCents: 30000);

    final GoalProgress progress =
        (await repository.getGoalsWithProgress()).single;
    expect(progress.savedCents, 150000);
    expect(progress.remainingCents, 350000);
    expect(progress.progress, 0.3);
    expect(await repository.getTransactions('goal'), hasLength(2));
    expect(await repository.getAllocatedCentsForMonth('2026-08'), 120000);
  });

  test('retirada preserva o histórico e impede saldo negativo', () async {
    await repository.createGoal(_goal());
    await repository.allocate(goalId: 'goal', amountCents: 100000);
    final GoalTransaction withdrawal = await repository.withdraw(
      goalId: 'goal',
      amountCents: 40000,
    );

    expect(withdrawal.changeCents, -40000);
    expect((await repository.getGoalProgress('goal'))?.savedCents, 60000);
    expect(await repository.getTransactions('goal'), hasLength(2));
    await expectLater(
      repository.withdraw(goalId: 'goal', amountCents: 70000),
      throwsStateError,
    );
  });

  test('editar e concluir a meta não apaga movimentações', () async {
    final SavingsGoal goal = _goal();
    await repository.createGoal(goal);
    await repository.allocate(goalId: goal.id, amountCents: 50000);
    await repository.updateGoal(
      goal.copyWith(
        name: 'Viagem atualizada',
        status: SavingsGoalStatus.completed,
        completedAt: DateTime(2026, 8, 20),
        updatedAt: DateTime(2026, 8, 20),
      ),
    );

    final GoalProgress progress =
        (await repository.getGoalsWithProgress()).single;
    expect(progress.goal.name, 'Viagem atualizada');
    expect(progress.goal.status, SavingsGoalStatus.completed);
    expect(progress.savedCents, 50000);
    expect(await repository.getTransactions(goal.id), hasLength(1));
  });
}

SavingsGoal _goal() {
  final DateTime createdAt = DateTime(2026, 8, 1);
  return SavingsGoal(
    id: 'goal',
    name: 'Viagem',
    targetCents: 500000,
    status: SavingsGoalStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
