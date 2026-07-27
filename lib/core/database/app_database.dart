import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  // Padrão Singleton: garante que o app abra o banco de dados apenas uma vez
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    // Se o banco já estiver aberto, apenas o retorna
    if (_database != null) return _database!;

    // Se não, cria a conexão do zero
    _database = await _initDB('finanse.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Descobre onde o celular guarda os aplicativos
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Abre o banco. A versão (version: 1) é importante caso a gente queira mudar algo no futuro
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Aqui criamos a tabela exata com os campos do nosso modelo Expense
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        categoryName TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        paymentMethod TEXT,
        isRecurring INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}