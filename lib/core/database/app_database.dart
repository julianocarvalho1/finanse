import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Gerencia o banco de dados local do aplicativo.
///
/// A classe utiliza o padrão Singleton para garantir que apenas uma conexão
/// com o banco permaneça aberta durante a execução do aplicativo.
class AppDatabase {
  AppDatabase._init();

  static final AppDatabase instance = AppDatabase._init();

  static const String _databaseName = 'finanse.db';
  static const int _databaseVersion = 5;

  static const String expensesTable = 'expenses';
  static const String recurringExpensesTable = 'recurring_expenses';
  static const String reserveTransactionsTable = 'reserve_transactions';

  static Database? _database;

  Future<Database> get database async {
    final Database? existingDatabase = _database;

    if (existingDatabase != null && existingDatabase.isOpen) {
      return existingDatabase;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String databaseDirectory = await getDatabasesPath();

    final String databasePath = join(databaseDirectory, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: _configureDatabase,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDatabase(Database db, int version) async {
    await _createExpensesTable(db);
    await _createRecurringExpensesTable(db);
    await _createReserveTransactionsTable(db);
    await _createIndexes(db);
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnWhenMissing(
        db: db,
        table: expensesTable,
        column: 'notes',
        definition: 'TEXT',
      );
    }

    if (oldVersion < 3) {
      await _createRecurringExpensesTable(db);

      await _addColumnWhenMissing(
        db: db,
        table: expensesTable,
        column: 'recurringExpenseId',
        definition: 'TEXT',
      );
    }
    if (oldVersion < 4) {
      await _addColumnWhenMissing(
        db: db,
        table: recurringExpensesTable,
        column: 'undoExpenseId',
        definition: 'TEXT',
      );

      await _addColumnWhenMissing(
        db: db,
        table: recurringExpensesTable,
        column: 'undoPreviousNextDate',
        definition: 'TEXT',
      );

      await _addColumnWhenMissing(
        db: db,
        table: recurringExpensesTable,
        column: 'undoPreviousLastRegisteredAt',
        definition: 'TEXT',
      );

      await _addColumnWhenMissing(
        db: db,
        table: recurringExpensesTable,
        column: 'undoPreviousRegisteredCount',
        definition: 'INTEGER',
      );
    }

    if (oldVersion < 5) {
      await _createReserveTransactionsTable(db);
    }

    await _createIndexes(db);
  }

  Future<void> _createExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $expensesTable (
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
  }

  Future<void> _createRecurringExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $recurringExpensesTable (
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

undoExpenseId TEXT,
undoPreviousNextDate TEXT,
undoPreviousLastRegisteredAt TEXT,
undoPreviousRegisteredCount INTEGER,

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
  }


  Future<void> _createReserveTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $reserveTransactionsTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(
          type IN ('add', 'withdraw', 'adjust')
        ),
        amount REAL NOT NULL CHECK(amount >= 0),
        previousBalance REAL NOT NULL CHECK(previousBalance >= 0),
        balanceAfter REAL NOT NULL CHECK(balanceAfter >= 0),
        note TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_date
      ON $expensesTable(date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_category
      ON $expensesTable(categoryName)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_recurring_id
      ON $expensesTable(recurringExpenseId)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recurring_expenses_next_date
      ON $recurringExpensesTable(nextDate)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recurring_expenses_active
      ON $recurringExpensesTable(isActive)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recurring_expenses_category
      ON $recurringExpensesTable(categoryName)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reserve_transactions_created_at
      ON $reserveTransactionsTable(createdAt)
    ''');
  }

  Future<void> _addColumnWhenMissing({
    required Database db,
    required String table,
    required String column,
    required String definition,
  }) async {
    final List<Map<String, Object?>> tableInformation = await db.rawQuery(
      'PRAGMA table_info($table)',
    );

    final bool columnAlreadyExists = tableInformation.any((
      Map<String, Object?> item,
    ) {
      return item['name'] == column;
    });

    if (columnAlreadyExists) {
      return;
    }

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> close() async {
    final Database? currentDatabase = _database;

    if (currentDatabase == null) {
      return;
    }

    if (currentDatabase.isOpen) {
      await currentDatabase.close();
    }

    _database = null;
  }
}
