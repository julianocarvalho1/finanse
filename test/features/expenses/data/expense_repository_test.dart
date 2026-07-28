import 'package:finanse/features/expenses/data/expense_repository.dart';
import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late ExpenseRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    await database.execute('''
      CREATE TABLE expenses (
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

    repository = ExpenseRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ExpenseRepository', () {
    test('insere e busca uma despesa pelo ID', () async {
      final DateTime expenseDate = DateTime(2026, 7, 28, 14, 30);

      final DateTime createdAt = DateTime(2026, 7, 28, 14);

      final Expense expense = Expense(
        id: 'expense-repository-1',
        amount: 159.90,
        categoryName: 'Alimentação',
        description: 'Compras do mercado',
        notes: 'Compra semanal',
        date: expenseDate,
        paymentMethod: 'Pix',
        isRecurring: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertExpense(expense);

      final Expense? savedExpense = await repository.getExpenseById(expense.id);

      expect(savedExpense, isNotNull);
      expect(savedExpense!.id, expense.id);
      expect(savedExpense.amount, 159.90);
      expect(savedExpense.categoryName, 'Alimentação');
      expect(savedExpense.description, 'Compras do mercado');
      expect(savedExpense.notes, 'Compra semanal');
      expect(savedExpense.date, expenseDate);
      expect(savedExpense.paymentMethod, 'Pix');
      expect(savedExpense.isRecurring, isFalse);
      expect(savedExpense.createdAt, createdAt);
      expect(savedExpense.updatedAt, createdAt);
    });

    test('atualiza uma despesa existente', () async {
      final DateTime createdAt = DateTime(2026, 7, 20, 10);

      final Expense originalExpense = Expense(
        id: 'expense-update-1',
        amount: 80,
        categoryName: 'Transporte',
        description: 'Combustível',
        date: DateTime(2026, 7, 20),
        paymentMethod: 'Dinheiro',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertExpense(originalExpense);

      final DateTime updatedAt = DateTime(2026, 7, 21, 15);

      final Expense updatedExpense = originalExpense.copyWith(
        amount: 125.50,
        categoryName: 'Automóvel',
        description: 'Abastecimento completo',
        paymentMethod: 'Pix',
        updatedAt: updatedAt,
      );

      await repository.updateExpense(updatedExpense);

      final Expense? savedExpense = await repository.getExpenseById(
        originalExpense.id,
      );

      expect(savedExpense, isNotNull);
      expect(savedExpense!.id, originalExpense.id);
      expect(savedExpense.amount, 125.50);
      expect(savedExpense.categoryName, 'Automóvel');
      expect(savedExpense.description, 'Abastecimento completo');
      expect(savedExpense.paymentMethod, 'Pix');
      expect(savedExpense.createdAt, createdAt);
      expect(savedExpense.updatedAt, updatedAt);
    });
    test('exclui uma despesa existente', () async {
      final DateTime createdAt = DateTime(2026, 7, 22, 9);

      final Expense expense = Expense(
        id: 'expense-delete-1',
        amount: 45.90,
        categoryName: 'Lazer',
        description: 'Cinema',
        date: DateTime(2026, 7, 22, 20),
        paymentMethod: 'Cartão',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertExpense(expense);

      final Expense? beforeDeletion = await repository.getExpenseById(
        expense.id,
      );

      expect(beforeDeletion, isNotNull);

      await repository.deleteExpense(expense.id);

      final Expense? afterDeletion = await repository.getExpenseById(
        expense.id,
      );

      expect(afterDeletion, isNull);
    });
    test('exclui a despesa e devolve o registro removido', () async {
      final DateTime createdAt = DateTime(2026, 7, 23, 9);

      final Expense expense = Expense(
        id: 'expense-delete-return-1',
        amount: 32.50,
        categoryName: 'Alimentação',
        description: 'Café da manhã',
        notes: 'Padaria',
        date: DateTime(2026, 7, 23, 8, 30),
        paymentMethod: 'Pix',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertExpense(expense);

      final Expense removedExpense = await repository.deleteExpenseAndReturn(
        expense.id,
      );

      expect(removedExpense.id, expense.id);
      expect(removedExpense.amount, 32.50);
      expect(removedExpense.categoryName, 'Alimentação');
      expect(removedExpense.description, 'Café da manhã');
      expect(removedExpense.notes, 'Padaria');
      expect(removedExpense.paymentMethod, 'Pix');

      final Expense? savedExpense = await repository.getExpenseById(expense.id);

      expect(savedExpense, isNull);
    });
    test('saveExpense insere e depois atualiza a mesma despesa', () async {
      final DateTime createdAt = DateTime(2026, 7, 24, 10);

      final Expense originalExpense = Expense(
        id: 'expense-save-1',
        amount: 60,
        categoryName: 'Casa',
        description: 'Produto de limpeza',
        date: DateTime(2026, 7, 24, 9),
        paymentMethod: 'Dinheiro',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.saveExpense(originalExpense);

      final Expense? insertedExpense = await repository.getExpenseById(
        originalExpense.id,
      );

      expect(insertedExpense, isNotNull);
      expect(insertedExpense!.amount, 60);
      expect(insertedExpense.description, 'Produto de limpeza');

      final DateTime updatedAt = DateTime(2026, 7, 25, 14);

      final Expense changedExpense = originalExpense.copyWith(
        amount: 85.90,
        description: 'Produtos de limpeza',
        paymentMethod: 'Pix',
        updatedAt: updatedAt,
      );

      await repository.saveExpense(changedExpense);

      final Expense? updatedExpense = await repository.getExpenseById(
        originalExpense.id,
      );

      expect(updatedExpense, isNotNull);
      expect(updatedExpense!.amount, 85.90);
      expect(updatedExpense.description, 'Produtos de limpeza');
      expect(updatedExpense.paymentMethod, 'Pix');
      expect(updatedExpense.createdAt, createdAt);
      expect(updatedExpense.updatedAt, updatedAt);
    });
    test('filtra despesas por período e calcula o total', () async {
      final DateTime createdAt = DateTime(2026, 7, 1, 8);

      final List<Expense> expenses = <Expense>[
        Expense(
          id: 'expense-before-period',
          amount: 10,
          categoryName: 'Outros',
          description: 'Antes do período',
          date: DateTime(2026, 6, 30, 23, 59),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        Expense(
          id: 'expense-period-start',
          amount: 30,
          categoryName: 'Alimentação',
          description: 'Início do período',
          date: DateTime(2026, 7, 1),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        Expense(
          id: 'expense-period-end',
          amount: 70,
          categoryName: 'Transporte',
          description: 'Último dia do período',
          date: DateTime(2026, 7, 31, 23, 59),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        Expense(
          id: 'expense-exclusive-end',
          amount: 100,
          categoryName: 'Moradia',
          description: 'Data final exclusiva',
          date: DateTime(2026, 8, 1),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ];

      for (final Expense expense in expenses) {
        await repository.insertExpense(expense);
      }

      final DateTime start = DateTime(2026, 7, 1);
      final DateTime endExclusive = DateTime(2026, 8, 1);

      final List<Expense> periodExpenses = await repository.getExpensesBetween(
        start: start,
        endExclusive: endExclusive,
      );

      final double total = await repository.getTotalBetween(
        start: start,
        endExclusive: endExclusive,
      );

      expect(periodExpenses, hasLength(2));

      expect(periodExpenses.map((Expense expense) => expense.id), <String>[
        'expense-period-end',
        'expense-period-start',
      ]);

      expect(total, 100);
    });
    test(
      'lista todas as despesas da mais recente para a mais antiga',
      () async {
        final DateTime createdAt = DateTime(2026, 7, 1, 8);

        final List<Expense> expenses = <Expense>[
          Expense(
            id: 'expense-oldest',
            amount: 20,
            categoryName: 'Outros',
            description: 'Despesa mais antiga',
            date: DateTime(2026, 7, 5, 10),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
          Expense(
            id: 'expense-newest',
            amount: 80,
            categoryName: 'Alimentação',
            description: 'Despesa mais recente',
            date: DateTime(2026, 7, 25, 18),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
          Expense(
            id: 'expense-middle',
            amount: 40,
            categoryName: 'Transporte',
            description: 'Despesa intermediária',
            date: DateTime(2026, 7, 15, 14),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ];

        for (final Expense expense in expenses) {
          await repository.insertExpense(expense);
        }

        final List<Expense> savedExpenses = await repository.getAllExpenses();

        expect(savedExpenses, hasLength(3));

        expect(savedExpenses.map((Expense expense) => expense.id), <String>[
          'expense-newest',
          'expense-middle',
          'expense-oldest',
        ]);
      },
    );

    test('rejeita um intervalo de datas inválido', () async {
      final DateTime start = DateTime(2026, 7, 20);

      await expectLater(
        repository.getExpensesBetween(start: start, endExclusive: start),
        throwsArgumentError,
      );

      await expectLater(
        repository.getTotalBetween(
          start: start,
          endExclusive: DateTime(2026, 7, 19),
        ),
        throwsArgumentError,
      );
    });

    test('lança erro ao atualizar uma despesa inexistente', () async {
      final DateTime createdAt = DateTime(2026, 7, 28, 10);

      final Expense nonexistentExpense = Expense(
        id: 'expense-does-not-exist',
        amount: 99.90,
        categoryName: 'Outros',
        description: 'Despesa inexistente',
        date: DateTime(2026, 7, 28),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await expectLater(
        repository.updateExpense(nonexistentExpense),
        throwsA(isA<StateError>()),
      );
    });

    test('lança erro ao excluir uma despesa inexistente', () async {
      await expectLater(
        repository.deleteExpense('expense-does-not-exist'),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        repository.deleteExpenseAndReturn('expense-does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });
    test('não permite inserir duas despesas com o mesmo ID', () async {
      final DateTime createdAt = DateTime(2026, 7, 28, 10);

      final Expense expense = Expense(
        id: 'expense-duplicate-1',
        amount: 50,
        categoryName: 'Outros',
        description: 'Primeira despesa',
        date: DateTime(2026, 7, 28),
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.insertExpense(expense);

      final Expense duplicateExpense = expense.copyWith(
        amount: 100,
        description: 'Despesa duplicada',
      );

      await expectLater(
        repository.insertExpense(duplicateExpense),
        throwsA(anything),
      );

      final Expense? savedExpense = await repository.getExpenseById(expense.id);

      expect(savedExpense, isNotNull);
      expect(savedExpense!.amount, 50);
      expect(savedExpense.description, 'Primeira despesa');
    });
    test('identifica uma despesa semelhante registrada recentemente', () async {
      final DateTime now = DateTime.now();

      final Expense expense = Expense(
        id: 'expense-similar-1',
        amount: 79.90,
        categoryName: 'Alimentação',
        description: 'Mercado',
        date: now,
        createdAt: now.subtract(const Duration(seconds: 30)),
        updatedAt: now,
      );

      await repository.insertExpense(expense);

      final bool hasSimilarExpense = await repository.hasSimilarRecentExpense(
        amount: 79.90,
        categoryName: 'Alimentação',
        interval: const Duration(minutes: 2),
      );

      final bool hasDifferentAmount = await repository.hasSimilarRecentExpense(
        amount: 80,
        categoryName: 'Alimentação',
        interval: const Duration(minutes: 2),
      );

      final bool hasDifferentCategory = await repository
          .hasSimilarRecentExpense(
            amount: 79.90,
            categoryName: 'Transporte',
            interval: const Duration(minutes: 2),
          );

      expect(hasSimilarExpense, isTrue);
      expect(hasDifferentAmount, isFalse);
      expect(hasDifferentCategory, isFalse);
    });
  });
}
