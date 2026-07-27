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
  static const int _databaseVersion = 2;

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
    final String databasePath = join(
      databaseDirectory,
      _databaseName,
    );

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

  Future<void> _createDatabase(
      Database db,
      int version,
      ) async {
    await db.execute('''
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
        table: 'expenses',
        column: 'notes',
        definition: 'TEXT',
      );

      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_date
      ON expenses(date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_expenses_category
      ON expenses(categoryName)
    ''');
  }

  Future<void> _addColumnWhenMissing({
    required Database db,
    required String table,
    required String column,
    required String definition,
  }) async {
    final List<Map<String, Object?>> tableInformation =
    await db.rawQuery(
      'PRAGMA table_info($table)',
    );

    final bool columnAlreadyExists = tableInformation.any(
          (Map<String, Object?> item) => item['name'] == column,
    );

    if (columnAlreadyExists) {
      return;
    }

    await db.execute(
      'ALTER TABLE $table ADD COLUMN $column $definition',
    );
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