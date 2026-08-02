import 'dart:convert';
import 'dart:io';

import 'package:finanse/core/database/app_database.dart';
import 'package:finanse/features/profile/data/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_selector/file_selector.dart' as file_selector;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late Directory temporaryDirectory;
  late BackupService backupService;

  final DateTime fixedNow = DateTime(2026, 7, 28, 10, 30);

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notificationsEnabled': true,
      'themeMode': 'dark',
      'useBiometrics': true,
    });

    temporaryDirectory = await Directory.systemTemp.createTemp(
      'finanse_backup_test_',
    );

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
        frequency TEXT NOT NULL,
        customIntervalDays INTEGER,
        nextDate TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        lastRegisteredAt TEXT,
        registeredCount INTEGER NOT NULL DEFAULT 0,
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
        createdAt TEXT NOT NULL
      )
    ''');

    backupService = BackupService(
      database: database,
      documentsDirectoryProvider: () async {
        return temporaryDirectory;
      },
      nowProvider: () => fixedNow,
    );
  });

  tearDown(() async {
    await database.close();

    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  group('BackupService', () {
    test(
      'cria um backup completo com despesas, recorrências e preferências',
      () async {
        await database.insert(AppDatabase.expensesTable, <String, Object?>{
          'id': 'expense-backup-1',
          'amount': 125.50,
          'categoryName': 'Alimentação',
          'description': 'Mercado',
          'notes': 'Compra semanal',
          'date': DateTime(2026, 7, 27, 18).toIso8601String(),
          'paymentMethod': 'Pix',
          'isRecurring': 0,
          'recurringExpenseId': null,
          'createdAt': DateTime(2026, 7, 27, 18).toIso8601String(),
          'updatedAt': DateTime(2026, 7, 27, 18).toIso8601String(),
        });

        await database
            .insert(AppDatabase.recurringExpensesTable, <String, Object?>{
              'id': 'recurring-backup-1',
              'amount': 89.90,
              'categoryName': 'Assinaturas',
              'description': 'Internet',
              'notes': null,
              'paymentMethod': 'Cartão',
              'frequency': 'monthly',
              'customIntervalDays': null,
              'nextDate': DateTime(2026, 8, 10, 9).toIso8601String(),
              'isActive': 1,
              'lastRegisteredAt': null,
              'registeredCount': 0,
              'createdAt': DateTime(2026, 7, 1).toIso8601String(),
              'updatedAt': DateTime(2026, 7, 1).toIso8601String(),
            });

        final CreatedBackup backup = await backupService.createBackup();

        expect(await backup.file.exists(), isTrue);
        expect(await backup.file.length(), greaterThan(0));

        expect(backup.fileName, 'finanse_backup_20260728_103000.finanse');

        expect(backup.createdAt, fixedNow);
        expect(backup.expenseCount, 1);
        expect(backup.recurringExpenseCount, 1);
        expect(backup.totalRecordCount, 2);

        final String fileContent = await backup.file.readAsString(
          encoding: utf8,
        );

        final Map<String, dynamic> document = Map<String, dynamic>.from(
          jsonDecode(fileContent) as Map,
        );

        expect(document['signature'], 'FINANSE_BACKUP');
        expect(document['formatVersion'], 3);
        expect(document['databaseVersion'], 5);

        expect(
          DateTime.parse(document['createdAt'] as String),
          fixedNow.toUtc(),
        );

        final Map<String, dynamic> integrity = Map<String, dynamic>.from(
          document['integrity'] as Map,
        );

        expect(integrity['expenseCount'], 1);
        expect(integrity['recurringExpenseCount'], 1);
        expect(integrity['reserveTransactionCount'], 0);
        expect(
          integrity['checksum'],
          isA<String>().having(
            (String checksum) => checksum.length,
            'tamanho',
            8,
          ),
        );

        final Map<String, dynamic> payload = Map<String, dynamic>.from(
          document['payload'] as Map,
        );

        final List<dynamic> expenses = payload['expenses'] as List<dynamic>;

        final List<dynamic> recurringExpenses =
            payload['recurringExpenses'] as List<dynamic>;
        final List<dynamic> reserveTransactions =
            payload['reserveTransactions'] as List<dynamic>;

        final Map<String, dynamic> preferences = Map<String, dynamic>.from(
          payload['preferences'] as Map,
        );

        expect(expenses, hasLength(1));
        expect(recurringExpenses, hasLength(1));
        expect(reserveTransactions, isEmpty);

        expect((expenses.first as Map)['id'], 'expense-backup-1');

        expect((recurringExpenses.first as Map)['id'], 'recurring-backup-1');

        expect(preferences['notificationsEnabled'], <String, dynamic>{
          'type': 'bool',
          'value': true,
        });

        expect(preferences['themeMode'], <String, dynamic>{
          'type': 'string',
          'value': 'dark',
        });

        expect(preferences.containsKey('useBiometrics'), isFalse);

        final SharedPreferences savedPreferences =
            await SharedPreferences.getInstance();

        expect(
          savedPreferences.getString('lastBackupAt'),
          fixedNow.toIso8601String(),
        );

        expect(
          savedPreferences.getString('lastBackupFileName'),
          backup.fileName,
        );
      },
    );
    test('restaura despesas, recorrências e preferências do backup', () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await database.insert(AppDatabase.expensesTable, <String, Object?>{
        'id': 'expense-original',
        'amount': 250.75,
        'categoryName': 'Moradia',
        'description': 'Conta original',
        'notes': 'Preservar no backup',
        'date': DateTime(2026, 7, 20, 12).toIso8601String(),
        'paymentMethod': 'Pix',
        'isRecurring': 0,
        'recurringExpenseId': null,
        'createdAt': DateTime(2026, 7, 20, 12).toIso8601String(),
        'updatedAt': DateTime(2026, 7, 20, 12).toIso8601String(),
      });

      await database
          .insert(AppDatabase.recurringExpensesTable, <String, Object?>{
            'id': 'recurring-original',
            'amount': 99.90,
            'categoryName': 'Assinaturas',
            'description': 'Internet original',
            'notes': null,
            'paymentMethod': 'Cartão',
            'frequency': 'monthly',
            'customIntervalDays': null,
            'nextDate': DateTime(2026, 8, 15, 9).toIso8601String(),
            'isActive': 1,
            'lastRegisteredAt': null,
            'registeredCount': 2,
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'updatedAt': DateTime(2026, 7, 15).toIso8601String(),
          });

      final CreatedBackup createdBackup = await backupService.createBackup();

      final String backupContent = await createdBackup.file.readAsString(
        encoding: utf8,
      );

      final Map<String, dynamic> document = Map<String, dynamic>.from(
        jsonDecode(backupContent) as Map,
      );

      await database.delete(AppDatabase.expensesTable);

      await database.delete(AppDatabase.recurringExpensesTable);

      await database.insert(AppDatabase.expensesTable, <String, Object?>{
        'id': 'expense-temporary',
        'amount': 10,
        'categoryName': 'Outros',
        'description': 'Será removida',
        'notes': null,
        'date': fixedNow.toIso8601String(),
        'paymentMethod': null,
        'isRecurring': 0,
        'recurringExpenseId': null,
        'createdAt': fixedNow.toIso8601String(),
        'updatedAt': fixedNow.toIso8601String(),
      });

      await preferences.setBool('notificationsEnabled', false);

      await preferences.setString('themeMode', 'light');

      await preferences.setBool('useBiometrics', false);

      await preferences.setString('temporaryPreference', 'remover');

      final SelectedBackup selectedBackup = SelectedBackup(
        file: file_selector.XFile(createdBackup.file.path),
        createdAt: createdBackup.createdAt,
        expenseCount: createdBackup.expenseCount,
        recurringExpenseCount: createdBackup.recurringExpenseCount,
        document: document,
      );

      final BackupRestoreResult result = await backupService.restoreBackup(
        selectedBackup,
      );

      expect(result.restoredAt, fixedNow);
      expect(result.expenseCount, 1);
      expect(result.recurringExpenseCount, 1);
      expect(result.totalRecordCount, 2);

      final List<Map<String, Object?>> expenses = await database.query(
        AppDatabase.expensesTable,
      );

      final List<Map<String, Object?>> recurringExpenses = await database.query(
        AppDatabase.recurringExpensesTable,
      );

      expect(expenses, hasLength(1));
      expect(expenses.first['id'], 'expense-original');
      expect(expenses.first['amount'], 250.75);
      expect(expenses.first['description'], 'Conta original');

      expect(recurringExpenses, hasLength(1));
      expect(recurringExpenses.first['id'], 'recurring-original');
      expect(recurringExpenses.first['registeredCount'], 2);

      expect(preferences.getBool('notificationsEnabled'), isTrue);

      expect(preferences.getString('themeMode'), 'dark');

      // substituída pelos dados do backup.
      expect(preferences.getBool('useBiometrics'), isFalse);

      expect(preferences.getString('temporaryPreference'), isNull);

      expect(
        preferences.getString('lastRestoreAt'),
        fixedNow.toIso8601String(),
      );

      expect(preferences.getString('lastBackupAt'), fixedNow.toIso8601String());
    });

    test('bloqueia a restauração quando o checksum não confere', () async {
      await database.insert(AppDatabase.expensesTable, <String, Object?>{
        'id': 'expense-checksum-1',
        'amount': 45.50,
        'categoryName': 'Alimentação',
        'description': 'Despesa original',
        'notes': null,
        'date': DateTime(2026, 7, 25, 12).toIso8601String(),
        'paymentMethod': 'Pix',
        'isRecurring': 0,
        'recurringExpenseId': null,
        'createdAt': DateTime(2026, 7, 25, 12).toIso8601String(),
        'updatedAt': DateTime(2026, 7, 25, 12).toIso8601String(),
      });

      final CreatedBackup createdBackup = await backupService.createBackup();

      final String backupContent = await createdBackup.file.readAsString(
        encoding: utf8,
      );

      final Map<String, dynamic> document = Map<String, dynamic>.from(
        jsonDecode(backupContent) as Map,
      );

      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        document['payload'] as Map,
      );

      final List<dynamic> expenses = List<dynamic>.from(
        payload['expenses'] as List,
      );

      final Map<String, dynamic> alteredExpense = Map<String, dynamic>.from(
        expenses.first as Map,
      );

      // Altera o conteúdo sem recalcular o checksum.
      alteredExpense['amount'] = 9999.99;

      expenses[0] = alteredExpense;
      payload['expenses'] = expenses;
      document['payload'] = payload;

      final SelectedBackup selectedBackup = SelectedBackup(
        file: file_selector.XFile(createdBackup.file.path),
        createdAt: createdBackup.createdAt,
        expenseCount: createdBackup.expenseCount,
        recurringExpenseCount: createdBackup.recurringExpenseCount,
        document: document,
      );

      await expectLater(
        backupService.restoreBackup(selectedBackup),
        throwsA(isA<BackupException>()),
      );

      // Como a validação falhou antes da restauração,
      // os dados atuais continuam preservados.
      final List<Map<String, Object?>> savedExpenses = await database.query(
        AppDatabase.expensesTable,
      );

      expect(savedExpenses, hasLength(1));
      expect(savedExpenses.first['id'], 'expense-checksum-1');
      expect(savedExpenses.first['amount'], 45.50);
    });
  });
}
