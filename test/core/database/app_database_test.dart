import 'package:finanse/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();

    final String databaseDirectory = await getDatabasesPath();

    databasePath = path.join(databaseDirectory, 'finanse.db');

    await databaseFactoryFfi.deleteDatabase(databasePath);
  });

  tearDown(() async {
    await AppDatabase.instance.close();

    await databaseFactoryFfi.deleteDatabase(databasePath);
  });

  group('AppDatabase', () {
    test(
      'migra o banco da versão 1 para a versão 4 preservando despesas',
      () async {
        final Database oldDatabase = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (Database database, int version) async {
              await database.execute('''
                CREATE TABLE expenses (
                  id TEXT PRIMARY KEY,
                  amount REAL NOT NULL,
                  categoryName TEXT NOT NULL,
                  description TEXT,
                  date TEXT NOT NULL,
                  paymentMethod TEXT,
                  isRecurring INTEGER NOT NULL DEFAULT 0,
                  createdAt TEXT NOT NULL,
                  updatedAt TEXT NOT NULL
                )
              ''');
            },
          ),
        );

        final DateTime createdAt = DateTime(2026, 1, 10, 8);

        await oldDatabase.insert('expenses', <String, Object?>{
          'id': 'expense-before-migration',
          'amount': 99.90,
          'categoryName': 'Alimentação',
          'description': 'Despesa antiga',
          'date': DateTime(2026, 1, 10, 12).toIso8601String(),
          'paymentMethod': 'Pix',
          'isRecurring': 0,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': createdAt.toIso8601String(),
        });

        await oldDatabase.close();

        final Database migratedDatabase = await AppDatabase.instance.database;

        expect(await migratedDatabase.getVersion(), 4);

        final List<Map<String, Object?>> expenseColumns = await migratedDatabase
            .rawQuery('PRAGMA table_info(expenses)');

        final Set<String> expenseColumnNames = expenseColumns
            .map((Map<String, Object?> column) => column['name'].toString())
            .toSet();

        expect(expenseColumnNames, contains('notes'));

        expect(expenseColumnNames, contains('recurringExpenseId'));

        final List<Map<String, Object?>> expenses = await migratedDatabase
            .query(AppDatabase.expensesTable);

        expect(expenses, hasLength(1));

        expect(expenses.first['id'], 'expense-before-migration');

        expect(expenses.first['amount'], 99.90);
        expect(expenses.first['description'], 'Despesa antiga');

        expect(expenses.first['notes'], isNull);
        expect(expenses.first['recurringExpenseId'], isNull);

        final List<Map<String, Object?>> recurringTables =
            await migratedDatabase.rawQuery(
              '''
          SELECT name
          FROM sqlite_master
          WHERE type = 'table'
            AND name = ?
          ''',
              <Object?>[AppDatabase.recurringExpensesTable],
            );

        expect(recurringTables, hasLength(1));

        final List<Map<String, Object?>> indexes = await migratedDatabase
            .rawQuery('''
          SELECT name
          FROM sqlite_master
          WHERE type = 'index'
            AND name IN (
              'idx_expenses_date',
              'idx_expenses_category',
              'idx_expenses_recurring_id',
              'idx_recurring_expenses_next_date',
              'idx_recurring_expenses_active',
              'idx_recurring_expenses_category'
            )
          ''');

        expect(indexes, hasLength(6));
      },
    );

    test(
      'migra o banco da versão 2 para a versão 4 preservando despesas',
      () async {
        final Database oldDatabase = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (Database database, int version) async {
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
                  createdAt TEXT NOT NULL,
                  updatedAt TEXT NOT NULL
                )
              ''');
            },
          ),
        );

        final DateTime createdAt = DateTime(2026, 5, 10, 8);

        await oldDatabase.insert('expenses', <String, Object?>{
          'id': 'expense-version-2',
          'amount': 150.75,
          'categoryName': 'Saúde',
          'description': 'Consulta',
          'notes': 'Despesa criada na versão 2',
          'date': DateTime(2026, 5, 10, 9).toIso8601String(),
          'paymentMethod': 'Pix',
          'isRecurring': 0,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': createdAt.toIso8601String(),
        });

        await oldDatabase.close();

        final Database migratedDatabase = await AppDatabase.instance.database;

        expect(await migratedDatabase.getVersion(), 4);

        final List<Map<String, Object?>> expenses = await migratedDatabase
            .query(AppDatabase.expensesTable);

        expect(expenses, hasLength(1));
        expect(expenses.first['id'], 'expense-version-2');
        expect(expenses.first['amount'], 150.75);
        expect(expenses.first['notes'], 'Despesa criada na versão 2');
        expect(expenses.first['recurringExpenseId'], isNull);

        final List<Map<String, Object?>> expenseColumns = await migratedDatabase
            .rawQuery('PRAGMA table_info(expenses)');

        final Set<String> expenseColumnNames = expenseColumns
            .map((Map<String, Object?> column) => column['name'].toString())
            .toSet();

        expect(expenseColumnNames, contains('notes'));

        expect(expenseColumnNames, contains('recurringExpenseId'));

        final List<Map<String, Object?>> recurringTables =
            await migratedDatabase.rawQuery(
              '''
          SELECT name
          FROM sqlite_master
          WHERE type = 'table'
            AND name = ?
          ''',
              <Object?>[AppDatabase.recurringExpensesTable],
            );

        expect(recurringTables, hasLength(1));
      },
    );
  });
}
