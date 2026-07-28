import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/recurring_expenses/data/recurring_expense_repository.dart';
import 'package:finanse/features/recurring_expenses/domain/recurring_expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late RecurringExpenseRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

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
      CREATE TABLE ${AppDatabase.recurringExpensesTable} (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL CHECK(amount > 0),
        categoryName TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        paymentMethod TEXT,
        frequency TEXT NOT NULL CHECK(
          frequency IN (
            'weekly',
            'biweekly',
            'monthly',
            'yearly',
            'custom'
          )
        ),
        customIntervalDays INTEGER,
        nextDate TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1 CHECK(
          isActive IN (0, 1)
        ),
        lastRegisteredAt TEXT,
        registeredCount INTEGER NOT NULL DEFAULT 0 CHECK(
          registeredCount >= 0
        ),
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        CHECK(
          frequency != 'custom'
          OR (
            customIntervalDays IS NOT NULL
            AND customIntervalDays > 0
          )
        )
      )
    ''');

    repository = RecurringExpenseRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('RecurringExpenseRepository', () {
    test('insere e busca uma recorrência pelo ID', () async {
      final DateTime createdAt = DateTime(2026, 7, 28, 9);

      final DateTime nextDate = DateTime(2026, 8, 10, 8, 30);

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-repository-1',
        amount: 950,
        categoryName: 'Moradia',
        description: 'Aluguel',
        notes: 'Vencimento mensal',
        paymentMethod: 'Pix',
        frequency: RecurringFrequency.monthly,
        nextDate: nextDate,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(recurringExpense);

      final RecurringExpense? savedRecurringExpense = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(savedRecurringExpense, isNotNull);
      expect(savedRecurringExpense!.id, recurringExpense.id);
      expect(savedRecurringExpense.amount, 950);
      expect(savedRecurringExpense.categoryName, 'Moradia');
      expect(savedRecurringExpense.description, 'Aluguel');
      expect(savedRecurringExpense.notes, 'Vencimento mensal');
      expect(savedRecurringExpense.paymentMethod, 'Pix');
      expect(savedRecurringExpense.frequency, RecurringFrequency.monthly);
      expect(savedRecurringExpense.customIntervalDays, isNull);
      expect(savedRecurringExpense.nextDate, nextDate);
      expect(savedRecurringExpense.isActive, isTrue);
      expect(savedRecurringExpense.registeredCount, 0);
      expect(savedRecurringExpense.createdAt, createdAt);
      expect(savedRecurringExpense.updatedAt, createdAt);
    });
    test('atualiza uma recorrência existente', () async {
      final DateTime createdAt = DateTime(2026, 7, 20, 9);

      final RecurringExpense originalRecurringExpense = RecurringExpense(
        id: 'recurring-update-1',
        amount: 120,
        categoryName: 'Saúde',
        description: 'Academia',
        notes: 'Plano mensal',
        paymentMethod: 'Cartão',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 5, 8),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(originalRecurringExpense);

      final DateTime updatedAt = DateTime(2026, 7, 28, 15);

      final RecurringExpense updatedRecurringExpense = originalRecurringExpense
          .copyWith(
            amount: 150,
            categoryName: 'Cuidados pessoais',
            description: 'Academia e natação',
            notes: null,
            paymentMethod: 'Pix',
            frequency: RecurringFrequency.custom,
            customIntervalDays: 15,
            nextDate: DateTime(2026, 8, 15, 8),
            updatedAt: updatedAt,
          );

      await repository.updateRecurringExpense(updatedRecurringExpense);

      final RecurringExpense? savedRecurringExpense = await repository
          .getRecurringExpenseById(originalRecurringExpense.id);

      expect(savedRecurringExpense, isNotNull);
      expect(savedRecurringExpense!.id, originalRecurringExpense.id);
      expect(savedRecurringExpense.amount, 150);
      expect(savedRecurringExpense.categoryName, 'Cuidados pessoais');
      expect(savedRecurringExpense.description, 'Academia e natação');
      expect(savedRecurringExpense.notes, isNull);
      expect(savedRecurringExpense.paymentMethod, 'Pix');
      expect(savedRecurringExpense.frequency, RecurringFrequency.custom);
      expect(savedRecurringExpense.customIntervalDays, 15);
      expect(savedRecurringExpense.nextDate, DateTime(2026, 8, 15, 8));
      expect(savedRecurringExpense.createdAt, createdAt);
      expect(savedRecurringExpense.updatedAt, updatedAt);
    });
    test(
      'saveRecurringExpense insere e depois atualiza a recorrência',
      () async {
        final DateTime createdAt = DateTime(2026, 7, 21, 10);

        final RecurringExpense originalRecurringExpense = RecurringExpense(
          id: 'recurring-save-1',
          amount: 75,
          categoryName: 'Assinaturas',
          description: 'Serviço de streaming',
          paymentMethod: 'Cartão',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 10, 9),
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        await repository.saveRecurringExpense(originalRecurringExpense);

        final RecurringExpense? insertedRecurringExpense = await repository
            .getRecurringExpenseById(originalRecurringExpense.id);

        expect(insertedRecurringExpense, isNotNull);
        expect(insertedRecurringExpense!.amount, 75);
        expect(insertedRecurringExpense.description, 'Serviço de streaming');
        expect(insertedRecurringExpense.frequency, RecurringFrequency.monthly);

        final DateTime updatedAt = DateTime(2026, 7, 29, 16);

        final RecurringExpense changedRecurringExpense =
            originalRecurringExpense.copyWith(
              amount: 89.90,
              description: 'Streaming familiar',
              paymentMethod: 'Pix',
              frequency: RecurringFrequency.yearly,
              nextDate: DateTime(2027, 8, 10, 9),
              updatedAt: updatedAt,
            );

        await repository.saveRecurringExpense(changedRecurringExpense);

        final RecurringExpense? updatedRecurringExpense = await repository
            .getRecurringExpenseById(originalRecurringExpense.id);

        expect(updatedRecurringExpense, isNotNull);
        expect(updatedRecurringExpense!.amount, 89.90);
        expect(updatedRecurringExpense.description, 'Streaming familiar');
        expect(updatedRecurringExpense.paymentMethod, 'Pix');
        expect(updatedRecurringExpense.frequency, RecurringFrequency.yearly);
        expect(updatedRecurringExpense.nextDate, DateTime(2027, 8, 10, 9));
        expect(updatedRecurringExpense.createdAt, createdAt);
        expect(updatedRecurringExpense.updatedAt, updatedAt);
      },
    );
    test(
      'lista recorrências ativas primeiro e permite ocultar pausadas',
      () async {
        final DateTime createdAt = DateTime(2026, 7, 1, 8);

        final RecurringExpense activeLater = RecurringExpense(
          id: 'recurring-active-later',
          amount: 100,
          categoryName: 'Assinaturas',
          description: 'Recorrência ativa posterior',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 9, 1),
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        final RecurringExpense pausedEarlier = RecurringExpense(
          id: 'recurring-paused-earlier',
          amount: 50,
          categoryName: 'Lazer',
          description: 'Recorrência pausada',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 7, 1),
          isActive: false,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        final RecurringExpense activeEarlier = RecurringExpense(
          id: 'recurring-active-earlier',
          amount: 75,
          categoryName: 'Saúde',
          description: 'Recorrência ativa anterior',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 1),
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        await repository.insertRecurringExpense(activeLater);
        await repository.insertRecurringExpense(pausedEarlier);
        await repository.insertRecurringExpense(activeEarlier);

        final List<RecurringExpense> allRecurringExpenses = await repository
            .getAllRecurringExpenses();

        expect(
          allRecurringExpenses.map(
            (RecurringExpense recurringExpense) => recurringExpense.id,
          ),
          <String>[
            'recurring-active-earlier',
            'recurring-active-later',
            'recurring-paused-earlier',
          ],
        );

        final List<RecurringExpense> activeRecurringExpenses = await repository
            .getActiveRecurringExpenses();

        expect(activeRecurringExpenses, hasLength(2));

        expect(
          activeRecurringExpenses.map(
            (RecurringExpense recurringExpense) => recurringExpense.id,
          ),
          <String>['recurring-active-earlier', 'recurring-active-later'],
        );
      },
    );
    test('lista e conta somente recorrências ativas que já venceram', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);
      final DateTime referenceDate = DateTime(2026, 8, 15, 12);

      final List<RecurringExpense> recurringExpenses = <RecurringExpense>[
        RecurringExpense(
          id: 'recurring-due-oldest',
          amount: 100,
          categoryName: 'Moradia',
          description: 'Recorrência vencida primeiro',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 5, 9),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        RecurringExpense(
          id: 'recurring-due-latest',
          amount: 80,
          categoryName: 'Assinaturas',
          description: 'Recorrência vencida depois',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 15, 10),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        RecurringExpense(
          id: 'recurring-future',
          amount: 60,
          categoryName: 'Saúde',
          description: 'Recorrência futura',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 20),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        RecurringExpense(
          id: 'recurring-paused-due',
          amount: 40,
          categoryName: 'Lazer',
          description: 'Recorrência vencida e pausada',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 1),
          isActive: false,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ];

      for (final RecurringExpense recurringExpense in recurringExpenses) {
        await repository.insertRecurringExpense(recurringExpense);
      }

      final List<RecurringExpense> dueRecurringExpenses = await repository
          .getDueRecurringExpenses(referenceDate: referenceDate);

      final int dueCount = await repository.getDueRecurringExpenseCount(
        referenceDate: referenceDate,
      );

      expect(dueRecurringExpenses, hasLength(2));

      expect(
        dueRecurringExpenses.map(
          (RecurringExpense recurringExpense) => recurringExpense.id,
        ),
        <String>['recurring-due-oldest', 'recurring-due-latest'],
      );

      expect(dueCount, 2);
    });
    test('pausa e reativa uma recorrência', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-active-state-1',
        amount: 120,
        categoryName: 'Saúde',
        description: 'Academia',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 10),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(recurringExpense);

      final RecurringExpense paused = await repository
          .setRecurringExpenseActive(id: recurringExpense.id, isActive: false);

      expect(paused.isActive, isFalse);

      final RecurringExpense? savedPaused = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(savedPaused, isNotNull);
      expect(savedPaused!.isActive, isFalse);

      final RecurringExpense reactivated = await repository
          .setRecurringExpenseActive(id: recurringExpense.id, isActive: true);

      expect(reactivated.isActive, isTrue);

      final RecurringExpense? savedReactivated = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(savedReactivated, isNotNull);
      expect(savedReactivated!.isActive, isTrue);
    });
    test('registra a recorrência e cria um gasto no histórico', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-register-1',
        amount: 220.50,
        categoryName: 'Contas',
        description: 'Energia elétrica',
        notes: 'Conta mensal',
        paymentMethod: 'Pix',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 31, 8),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(recurringExpense);

      final DateTime registeredAt = DateTime(2026, 8, 31, 12, 30);

      final DateTime expenseDate = DateTime(2026, 8, 30, 9);

      final RecurringRegistrationResult result = await repository
          .registerRecurringExpense(
            recurringExpenseId: recurringExpense.id,
            registeredAt: registeredAt,
            expenseDate: expenseDate,
          );

      expect(
        result.expense.id,
        '${recurringExpense.id}_'
        '${registeredAt.microsecondsSinceEpoch}',
      );

      expect(result.expense.amount, 220.50);
      expect(result.expense.categoryName, 'Contas');
      expect(result.expense.description, 'Energia elétrica');
      expect(result.expense.notes, 'Conta mensal');
      expect(result.expense.paymentMethod, 'Pix');
      expect(result.expense.date, expenseDate);
      expect(result.expense.isRecurring, isTrue);
      expect(result.expense.createdAt, registeredAt);
      expect(result.expense.updatedAt, registeredAt);

      expect(
        result.previousRecurringExpense.nextDate,
        DateTime(2026, 8, 31, 8),
      );

      expect(result.previousRecurringExpense.registeredCount, 0);

      expect(result.updatedRecurringExpense.nextDate, DateTime(2026, 9, 30, 8));

      expect(result.updatedRecurringExpense.lastRegisteredAt, registeredAt);

      expect(result.updatedRecurringExpense.registeredCount, 1);

      expect(result.updatedRecurringExpense.updatedAt, registeredAt);

      final List<Map<String, Object?>> expenseRows = await database.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: <Object?>[result.expense.id],
      );

      expect(expenseRows, hasLength(1));
      expect(expenseRows.first['recurringExpenseId'], recurringExpense.id);
      expect(expenseRows.first['isRecurring'], 1);
      expect(expenseRows.first['amount'], 220.50);

      final RecurringExpense? savedRecurringExpense = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(savedRecurringExpense, isNotNull);
      expect(savedRecurringExpense!.nextDate, DateTime(2026, 9, 30, 8));
      expect(savedRecurringExpense.lastRegisteredAt, registeredAt);
      expect(savedRecurringExpense.registeredCount, 1);
    });
    test('desfaz o registro e restaura a recorrência anterior', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final DateTime previousRegistrationDate = DateTime(2026, 7, 31, 12);

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-undo-1',
        amount: 180,
        categoryName: 'Contas',
        description: 'Internet',
        paymentMethod: 'Pix',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 31, 8),
        lastRegisteredAt: previousRegistrationDate,
        registeredCount: 2,
        createdAt: createdAt,
        updatedAt: previousRegistrationDate,
      );

      await repository.insertRecurringExpense(recurringExpense);

      final DateTime registeredAt = DateTime(2026, 8, 31, 14);

      final RecurringRegistrationResult result = await repository
          .registerRecurringExpense(
            recurringExpenseId: recurringExpense.id,
            registeredAt: registeredAt,
            expenseDate: DateTime(2026, 8, 31, 10),
          );

      final List<Map<String, Object?>> rowsBeforeUndo = await database.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: <Object?>[result.expense.id],
      );

      expect(rowsBeforeUndo, hasLength(1));
      expect(result.updatedRecurringExpense.registeredCount, 3);

      await repository.undoRegistration(result);

      final List<Map<String, Object?>> rowsAfterUndo = await database.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: <Object?>[result.expense.id],
      );

      expect(rowsAfterUndo, isEmpty);

      final RecurringExpense? restoredRecurringExpense = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(restoredRecurringExpense, isNotNull);
      expect(restoredRecurringExpense!.nextDate, DateTime(2026, 8, 31, 8));
      expect(
        restoredRecurringExpense.lastRegisteredAt,
        previousRegistrationDate,
      );
      expect(restoredRecurringExpense.registeredCount, 2);
      expect(restoredRecurringExpense.updatedAt, previousRegistrationDate);
    });
    test('não registra uma recorrência pausada', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final DateTime nextDate = DateTime(2026, 8, 10, 9);

      final RecurringExpense pausedRecurringExpense = RecurringExpense(
        id: 'recurring-paused-register-1',
        amount: 99.90,
        categoryName: 'Assinaturas',
        description: 'Serviço pausado',
        frequency: RecurringFrequency.monthly,
        nextDate: nextDate,
        isActive: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(pausedRecurringExpense);

      await expectLater(
        repository.registerRecurringExpense(
          recurringExpenseId: pausedRecurringExpense.id,
          registeredAt: DateTime(2026, 8, 10, 12),
        ),
        throwsA(isA<StateError>()),
      );

      final List<Map<String, Object?>> expenseRows = await database.query(
        AppDatabase.expensesTable,
      );

      expect(expenseRows, isEmpty);

      final RecurringExpense? savedRecurringExpense = await repository
          .getRecurringExpenseById(pausedRecurringExpense.id);

      expect(savedRecurringExpense, isNotNull);
      expect(savedRecurringExpense!.isActive, isFalse);
      expect(savedRecurringExpense.nextDate, nextDate);
      expect(savedRecurringExpense.registeredCount, 0);
      expect(savedRecurringExpense.lastRegisteredAt, isNull);
    });
    test('exclui a recorrência e devolve o registro removido', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-delete-return-1',
        amount: 145.90,
        categoryName: 'Saúde',
        description: 'Plano de saúde',
        notes: 'Vencimento mensal',
        paymentMethod: 'Débito automático',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 15, 9),
        registeredCount: 3,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(recurringExpense);

      final RecurringExpense removedRecurringExpense = await repository
          .deleteRecurringExpenseAndReturn(recurringExpense.id);

      expect(removedRecurringExpense.id, recurringExpense.id);
      expect(removedRecurringExpense.amount, 145.90);
      expect(removedRecurringExpense.categoryName, 'Saúde');
      expect(removedRecurringExpense.description, 'Plano de saúde');
      expect(removedRecurringExpense.notes, 'Vencimento mensal');
      expect(removedRecurringExpense.paymentMethod, 'Débito automático');
      expect(removedRecurringExpense.frequency, RecurringFrequency.monthly);
      expect(removedRecurringExpense.registeredCount, 3);

      final RecurringExpense? savedRecurringExpense = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(savedRecurringExpense, isNull);
    });
    test('exclui a recorrência sem apagar o gasto já registrado', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-delete-history-1',
        amount: 210,
        categoryName: 'Contas',
        description: 'Conta de água',
        paymentMethod: 'Pix',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 10, 9),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertRecurringExpense(recurringExpense);

      final RecurringRegistrationResult result = await repository
          .registerRecurringExpense(
            recurringExpenseId: recurringExpense.id,
            registeredAt: DateTime(2026, 8, 10, 12),
          );

      await repository.deleteRecurringExpense(recurringExpense.id);

      final RecurringExpense? savedRecurringExpense = await repository
          .getRecurringExpenseById(recurringExpense.id);

      expect(savedRecurringExpense, isNull);

      final List<Map<String, Object?>> expenseRows = await database.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: <Object?>[result.expense.id],
      );

      expect(expenseRows, hasLength(1));
      expect(expenseRows.first['recurringExpenseId'], recurringExpense.id);
      expect(expenseRows.first['amount'], 210);
    });
    test('não registra uma recorrência inexistente', () async {
      await expectLater(
        repository.registerRecurringExpense(
          recurringExpenseId: 'recurring-does-not-exist',
          registeredAt: DateTime(2026, 8, 10, 12),
        ),
        throwsA(isA<StateError>()),
      );

      final List<Map<String, Object?>> expenseRows = await database.query(
        AppDatabase.expensesTable,
      );

      expect(expenseRows, isEmpty);
    });
  });
}
