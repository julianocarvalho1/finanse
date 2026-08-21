import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/reserve/data/reserve_repository.dart';
import 'package:finanse/features/reserve/domain/reserve_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late ReserveRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

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

    repository = ReserveRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('registra adição, retirada e ajuste preservando o saldo', () async {
    final ReserveTransaction added = await repository.addAmount(500);
    final ReserveTransaction withdrawn = await repository.withdrawAmount(120);
    final ReserveTransaction adjusted = await repository.adjustBalance(450);

    expect(added.previousBalance, 0);
    expect(added.balanceAfter, 500);

    expect(withdrawn.previousBalance, 500);
    expect(withdrawn.balanceAfter, 380);

    expect(adjusted.previousBalance, 380);
    expect(adjusted.balanceAfter, 450);

    expect(await repository.getCurrentBalance(), 450);

    final List<ReserveTransaction> transactions = await repository
        .getTransactions();

    expect(transactions, hasLength(3));
    expect(transactions.first.type, ReserveTransactionType.adjust);
  });

  test('impede retirada maior que o saldo atual', () async {
    await repository.addAmount(100);

    await expectLater(
      repository.withdrawAmount(120),
      throwsA(isA<StateError>()),
    );

    expect(await repository.getCurrentBalance(), 100);
  });

  test('migra saldo legado somente quando o histórico está vazio', () async {
    final ReserveTransaction? migrated = await repository.migrateLegacyBalance(
      750,
    );

    expect(migrated, isNotNull);
    expect(await repository.getCurrentBalance(), 750);

    final ReserveTransaction? ignored = await repository.migrateLegacyBalance(
      900,
    );

    expect(ignored, isNull);
    expect(await repository.getCurrentBalance(), 750);
  });

  test('rastreia destinação por mês sem tratá-la como gasto', () async {
    await repository.addAmount(
      3200,
      originYearMonth: '2026-08',
      note: 'Resultado do mês',
    );
    await repository.addAmount(100);

    expect(await repository.getAllocatedCentsForMonth('2026-08'), 320000);
    expect(await repository.getAllocatedCentsForMonth('2026-09'), 0);
    expect(await repository.getCurrentBalance(), 3300);
  });
}
