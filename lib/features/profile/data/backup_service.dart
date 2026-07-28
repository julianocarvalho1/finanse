import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

/// Informações de um backup criado pelo aplicativo.
class CreatedBackup {
  const CreatedBackup({
    required this.file,
    required this.createdAt,
    required this.expenseCount,
    required this.recurringExpenseCount,
  });

  final File file;
  final DateTime createdAt;
  final int expenseCount;
  final int recurringExpenseCount;

  String get fileName {
    return path.basename(file.path);
  }

  int get totalRecordCount {
    return expenseCount + recurringExpenseCount;
  }
}

/// Backup escolhido pelo usuário e já validado.
class SelectedBackup {
  const SelectedBackup({
    required this.file,
    required this.createdAt,
    required this.expenseCount,
    required this.recurringExpenseCount,
    required this.document,
  });

  final file_selector.XFile file;
  final DateTime createdAt;
  final int expenseCount;
  final int recurringExpenseCount;

  /// Documento completo mantido em memória para a restauração.
  final Map<String, dynamic> document;

  String get fileName {
    if (file.name.trim().isNotEmpty) {
      return file.name;
    }

    return path.basename(file.path);
  }

  int get totalRecordCount {
    return expenseCount + recurringExpenseCount;
  }
}

/// Resultado final de uma restauração.
class BackupRestoreResult {
  const BackupRestoreResult({
    required this.restoredAt,
    required this.expenseCount,
    required this.recurringExpenseCount,
  });

  final DateTime restoredAt;
  final int expenseCount;
  final int recurringExpenseCount;

  int get totalRecordCount {
    return expenseCount + recurringExpenseCount;
  }
}

/// Falha conhecida durante backup ou restauração.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

/// Cria, valida, compartilha e restaura backups do Finanse.
class BackupService {
  BackupService({
    AppDatabase? appDatabase,
    Database? database,
    Future<Directory> Function()? documentsDirectoryProvider,
    DateTime Function()? nowProvider,
  }) : assert(
         appDatabase == null || database == null,
         'Informe AppDatabase ou Database, não os dois.',
       ),
       _appDatabase = appDatabase ?? AppDatabase.instance,
       _injectedDatabase = database,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _nowProvider = nowProvider ?? DateTime.now;

  static final BackupService instance = BackupService();

  final AppDatabase _appDatabase;
  final Database? _injectedDatabase;
  final Future<Directory> Function() _documentsDirectoryProvider;

  final DateTime Function() _nowProvider;

  Future<Database> get _database async {
    final Database? injectedDatabase = _injectedDatabase;

    if (injectedDatabase != null) {
      return injectedDatabase;
    }

    return _appDatabase.database;
  }

  static const String _signature = 'FINANSE_BACKUP';

  static const int _backupFormatVersion = 2;

  static const Set<int> _supportedBackupFormatVersions = <int>{1, 2};

  static const int _databaseVersion = 3;

  static const String _lastBackupAtKey = 'lastBackupAt';

  static const String _lastBackupFileNameKey = 'lastBackupFileName';

  static const String _lastRestoreAtKey = 'lastRestoreAt';

  /// Preferências que não devem ser copiadas entre aparelhos.
  static const Set<String> _protectedPreferenceKeys = <String>{
    'useBiometrics',
    _lastBackupAtKey,
    _lastBackupFileNameKey,
    _lastRestoreAtKey,
  };

  final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Cria um arquivo completo de backup.
  Future<CreatedBackup> createBackup() async {
    try {
      final Database database = await _database;

      final List<Map<String, Object?>> expenses = await database.query(
        AppDatabase.expensesTable,
        orderBy: 'date ASC',
      );

      final List<Map<String, Object?>> recurringExpenses = await database.query(
        AppDatabase.recurringExpensesTable,
        orderBy: 'createdAt ASC',
      );

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final Map<String, dynamic> payload = <String, dynamic>{
        'expenses': expenses
            .map<Map<String, Object?>>((Map<String, Object?> row) {
              return Map<String, Object?>.from(row);
            })
            .toList(growable: false),
        'recurringExpenses': recurringExpenses
            .map<Map<String, Object?>>((Map<String, Object?> row) {
              return Map<String, Object?>.from(row);
            })
            .toList(growable: false),
        'preferences': _encodePreferences(preferences),
      };

      final DateTime createdAt = _nowProvider();

      final String checksum = _calculatePayloadChecksum(payload);

      final Map<String, dynamic> document = <String, dynamic>{
        'signature': _signature,
        'formatVersion': _backupFormatVersion,
        'databaseVersion': _databaseVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'application': <String, dynamic>{'name': 'Finanse', 'version': '1.0.0'},
        'integrity': <String, dynamic>{
          'checksum': checksum,
          'expenseCount': expenses.length,
          'recurringExpenseCount': recurringExpenses.length,
        },
        'payload': payload,
      };

      await _documentsDirectoryProvider();

      final Directory documentsDirectory = await _documentsDirectoryProvider();

      final Directory backupDirectory = Directory(
        path.join(documentsDirectory.path, 'backups'),
      );

      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      final String fileName =
          'finanse_backup_'
          '${_fileDateFormat.format(createdAt)}'
          '.finanse';

      final File backupFile = File(path.join(backupDirectory.path, fileName));

      const JsonEncoder encoder = JsonEncoder.withIndent('  ');

      await backupFile.writeAsString(
        encoder.convert(document),
        encoding: utf8,
        flush: true,
      );

      if (!await backupFile.exists()) {
        throw const BackupException('O arquivo de backup não pôde ser criado.');
      }

      final int fileSize = await backupFile.length();

      if (fileSize <= 0) {
        throw const BackupException(
          'O arquivo de backup foi criado sem conteúdo.',
        );
      }

      await preferences.setString(
        _lastBackupAtKey,
        createdAt.toIso8601String(),
      );

      await preferences.setString(_lastBackupFileNameKey, fileName);

      return CreatedBackup(
        file: backupFile,
        createdAt: createdAt,
        expenseCount: expenses.length,
        recurringExpenseCount: recurringExpenses.length,
      );
    } on BackupException {
      rethrow;
    } catch (error, stackTrace) {
      stderr.writeln(
        'Erro ao criar backup: '
        '$error\n$stackTrace',
      );

      throw const BackupException('Não foi possível criar o backup.');
    }
  }

  /// Abre o painel de compartilhamento do aparelho.
  Future<void> shareBackup(CreatedBackup backup) async {
    try {
      await share_plus.SharePlus.instance.share(
        share_plus.ShareParams(
          title: 'Backup do Finanse',
          subject: 'Backup dos dados do Finanse',
          text:
              'Arquivo de backup do Finanse. '
              'Guarde este arquivo em um local seguro.',
          files: <share_plus.XFile>[
            share_plus.XFile(
              backup.file.path,
              mimeType: 'application/octet-stream',
            ),
          ],
          fileNameOverrides: <String>[backup.fileName],
        ),
      );
    } catch (error, stackTrace) {
      stderr.writeln(
        'Erro ao compartilhar backup: '
        '$error\n$stackTrace',
      );

      throw const BackupException(
        'O backup foi criado, mas não foi possível abrir o compartilhamento.',
      );
    }
  }

  /// Permite escolher um backup no explorador do Android.
  ///
  /// Retorna null quando o usuário cancela a seleção.
  Future<SelectedBackup?> selectBackupFile() async {
    try {
      final file_selector.XFile? selectedFile = await file_selector.openFile(
        confirmButtonText: 'Selecionar',
      );

      if (selectedFile == null) {
        return null;
      }

      final List<int> fileBytes = await selectedFile.readAsBytes();

      if (fileBytes.isEmpty) {
        throw const BackupException('O arquivo selecionado está vazio.');
      }

      final String content = _decodeBackupContent(fileBytes);

      final dynamic decoded;

      try {
        decoded = jsonDecode(content);
      } on FormatException catch (error, stackTrace) {
        stderr.writeln(
          'JSON inválido ao selecionar backup: '
          '$error\n$stackTrace',
        );

        throw const BackupException(
          'O arquivo selecionado não contém '
          'um backup válido do Finanse.',
        );
      }

      if (decoded is! Map) {
        throw const BackupException(
          'O formato do arquivo de backup é inválido.',
        );
      }

      final Map<String, dynamic> document = Map<String, dynamic>.from(decoded);

      final _ValidatedBackup validated = _validateDocument(document);

      return SelectedBackup(
        file: selectedFile,
        createdAt: validated.createdAt,
        expenseCount: validated.expenses.length,
        recurringExpenseCount: validated.recurringExpenses.length,
        document: document,
      );
    } on BackupException {
      rethrow;
    } catch (error, stackTrace) {
      stderr.writeln(
        'Erro ao selecionar backup: '
        '$error\n$stackTrace',
      );

      throw const BackupException(
        'Não foi possível abrir o arquivo de backup.',
      );
    }
  }

  /// Substitui os dados atuais pelos dados do backup.
  Future<BackupRestoreResult> restoreBackup(
    SelectedBackup selectedBackup,
  ) async {
    try {
      // O documento é validado novamente imediatamente antes
      // da operação destrutiva.
      final _ValidatedBackup validated = _validateDocument(
        selectedBackup.document,
      );

      final Database database = await _database;

      await database.transaction<void>((Transaction transaction) async {
        await transaction.delete(AppDatabase.expensesTable);

        await transaction.delete(AppDatabase.recurringExpensesTable);

        for (final Map<String, Object?> row in validated.recurringExpenses) {
          await transaction.insert(
            AppDatabase.recurringExpensesTable,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final Map<String, Object?> row in validated.expenses) {
          await transaction.insert(
            AppDatabase.expensesTable,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await _restorePreferences(
        preferences: preferences,
        encodedPreferences: validated.preferences,
      );

      final DateTime restoredAt = _nowProvider();

      await preferences.setString(
        _lastRestoreAtKey,
        restoredAt.toIso8601String(),
      );

      return BackupRestoreResult(
        restoredAt: restoredAt,
        expenseCount: validated.expenses.length,
        recurringExpenseCount: validated.recurringExpenses.length,
      );
    } on BackupException {
      rethrow;
    } catch (error, stackTrace) {
      stderr.writeln(
        'Erro ao restaurar backup: '
        '$error\n$stackTrace',
      );

      throw const BackupException(
        'Não foi possível restaurar o backup. '
        'Os dados atuais foram preservados sempre que possível.',
      );
    }
  }

  /// Recupera a data do último backup criado neste aparelho.
  Future<DateTime?> getLastBackupDate() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? value = preferences.getString(_lastBackupAtKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Map<String, dynamic> _encodePreferences(SharedPreferences preferences) {
    final List<String> keys = preferences.getKeys().toList()..sort();

    final Map<String, dynamic> encodedPreferences = <String, dynamic>{};

    for (final String key in keys) {
      if (_protectedPreferenceKeys.contains(key)) {
        continue;
      }

      final Object? value = preferences.get(key);

      if (value is bool) {
        encodedPreferences[key] = <String, dynamic>{
          'type': 'bool',
          'value': value,
        };

        continue;
      }

      if (value is int) {
        encodedPreferences[key] = <String, dynamic>{
          'type': 'int',
          'value': value,
        };

        continue;
      }

      if (value is double) {
        encodedPreferences[key] = <String, dynamic>{
          'type': 'double',
          'value': value,
        };

        continue;
      }

      if (value is String) {
        encodedPreferences[key] = <String, dynamic>{
          'type': 'string',
          'value': value,
        };

        continue;
      }

      if (value is List<String>) {
        encodedPreferences[key] = <String, dynamic>{
          'type': 'stringList',
          'value': value,
        };
      }
    }

    return encodedPreferences;
  }

  Future<void> _restorePreferences({
    required SharedPreferences preferences,
    required Map<String, dynamic> encodedPreferences,
  }) async {
    final Set<String> currentKeys = preferences.getKeys();

    for (final String key in currentKeys) {
      if (_protectedPreferenceKeys.contains(key)) {
        continue;
      }

      await preferences.remove(key);
    }

    for (final MapEntry<String, dynamic> entry in encodedPreferences.entries) {
      final String key = entry.key;

      if (_protectedPreferenceKeys.contains(key)) {
        continue;
      }

      final dynamic rawEntry = entry.value;

      if (rawEntry is! Map) {
        throw const BackupException(
          'Uma configuração do backup está danificada.',
        );
      }

      final Map<String, dynamic> preference = Map<String, dynamic>.from(
        rawEntry,
      );

      final String? type = preference['type'] as String?;

      final dynamic value = preference['value'];

      switch (type) {
        case 'bool':
          if (value is! bool) {
            throw const BackupException(
              'Uma configuração booleana do backup é inválida.',
            );
          }

          await preferences.setBool(key, value);

        case 'int':
          if (value is! num) {
            throw const BackupException(
              'Uma configuração numérica do backup é inválida.',
            );
          }

          await preferences.setInt(key, value.toInt());

        case 'double':
          if (value is! num) {
            throw const BackupException(
              'Uma configuração decimal do backup é inválida.',
            );
          }

          await preferences.setDouble(key, value.toDouble());

        case 'string':
          if (value is! String) {
            throw const BackupException(
              'Uma configuração de texto do backup é inválida.',
            );
          }

          await preferences.setString(key, _repairTextEncoding(value));

        case 'stringList':
          if (value is! List) {
            throw const BackupException(
              'Uma lista de configurações do backup é inválida.',
            );
          }

          await preferences.setStringList(
            key,
            value
                .map<String>((dynamic item) {
                  if (item is! String) {
                    throw const BackupException(
                      'Uma lista de configurações contém um valor inválido.',
                    );
                  }

                  return _repairTextEncoding(item);
                })
                .toList(growable: false),
          );

        default:
          throw const BackupException(
            'O backup contém um tipo de configuração desconhecido.',
          );
      }
    }
  }

  String _decodeBackupContent(List<int> fileBytes) {
    String content;

    try {
      content = utf8.decode(fileBytes, allowMalformed: false);
    } on FormatException {
      try {
        content = latin1.decode(fileBytes, allowInvalid: false);
      } catch (error) {
        throw const BackupException(
          'A codificação do arquivo de backup '
          'não é compatível.',
        );
      }
    }

    // Remove BOM, bytes nulos e espaços externos que alguns
    // gerenciadores de arquivos podem acrescentar.
    content = content.replaceAll('\uFEFF', '').replaceAll('\u0000', '').trim();

    final int jsonStart = content.indexOf('{');
    final int jsonEnd = content.lastIndexOf('}');

    if (jsonStart < 0 || jsonEnd < jsonStart) {
      throw const BackupException(
        'O arquivo selecionado não contém '
        'um documento de backup.',
      );
    }

    // Mantém somente o objeto JSON. Isso evita que nomes,
    // cabeçalhos ou caracteres externos impeçam a leitura.
    return content.substring(jsonStart, jsonEnd + 1);
  }

  _ValidatedBackup _validateDocument(Map<String, dynamic> document) {
    if (document['signature'] != _signature) {
      throw const BackupException('Este arquivo não pertence ao Finanse.');
    }

    final dynamic rawFormatVersion = document['formatVersion'];

    if (rawFormatVersion is! num) {
      throw const BackupException('A versão do arquivo de backup é inválida.');
    }

    final int formatVersion = rawFormatVersion.toInt();

    if (!_supportedBackupFormatVersions.contains(formatVersion)) {
      throw const BackupException(
        'Esta versão do arquivo de backup não é compatível.',
      );
    }

    final String? createdAtText = document['createdAt'] as String?;

    final DateTime? createdAt = createdAtText == null
        ? null
        : DateTime.tryParse(createdAtText);

    if (createdAt == null) {
      throw const BackupException('A data de criação do backup é inválida.');
    }

    final dynamic rawPayload = document['payload'];

    if (rawPayload is! Map) {
      throw const BackupException(
        'O conteúdo principal do backup está ausente.',
      );
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(rawPayload);

    final dynamic rawExpenses = payload['expenses'];

    final dynamic rawRecurringExpenses = payload['recurringExpenses'];

    final dynamic rawPreferences = payload['preferences'];

    if (rawExpenses is! List ||
        rawRecurringExpenses is! List ||
        rawPreferences is! Map) {
      throw const BackupException('O conteúdo do backup está incompleto.');
    }

    final List<Map<String, Object?>> expenses = rawExpenses
        .map<Map<String, Object?>>((dynamic row) {
          return _validateExpenseRow(row);
        })
        .toList(growable: false);

    final List<Map<String, Object?>> recurringExpenses = rawRecurringExpenses
        .map<Map<String, Object?>>((dynamic row) {
          return _validateRecurringExpenseRow(row);
        })
        .toList(growable: false);

    final Map<String, dynamic> preferences = Map<String, dynamic>.from(
      rawPreferences,
    );

    final dynamic rawIntegrity = document['integrity'];

    if (rawIntegrity is! Map) {
      throw const BackupException(
        'As informações de integridade do backup estão ausentes.',
      );
    }

    final Map<String, dynamic> integrity = Map<String, dynamic>.from(
      rawIntegrity,
    );

    final dynamic expectedExpenseCount = integrity['expenseCount'];

    final dynamic expectedRecurringCount = integrity['recurringExpenseCount'];

    if (expectedExpenseCount is! num ||
        expectedExpenseCount.toInt() != expenses.length) {
      throw const BackupException(
        'A quantidade de despesas do backup não confere.',
      );
    }

    if (expectedRecurringCount is! num ||
        expectedRecurringCount.toInt() != recurringExpenses.length) {
      throw const BackupException(
        'A quantidade de despesas recorrentes do backup não confere.',
      );
    }

    final String? expectedChecksum = integrity['checksum'] as String?;

    if (expectedChecksum == null || expectedChecksum.trim().isEmpty) {
      throw const BackupException(
        'As informações de integridade do backup estão incompletas.',
      );
    }

    final String actualChecksum = _calculatePayloadChecksum(payload);

    if (formatVersion >= 2 && expectedChecksum != actualChecksum) {
      throw const BackupException(
        'O arquivo de backup está corrompido ou foi alterado.',
      );
    }

    // A versão 1 utilizava a ordem interna do JSON no cálculo.
    // Ela pode apresentar divergência mesmo quando o arquivo está íntegro.
    // Os registros antigos continuam sendo rigorosamente validados acima.
    if (formatVersion == 1 && expectedChecksum != actualChecksum) {
      stderr.writeln(
        'Backup legado versão 1 com checksum divergente. '
        'Restauração permitida após validação estrutural completa.',
      );
    }

    return _ValidatedBackup(
      createdAt: createdAt.toLocal(),
      expenses: expenses,
      recurringExpenses: recurringExpenses,
      preferences: preferences,
    );
  }

  Map<String, Object?> _validateExpenseRow(dynamic rawRow) {
    if (rawRow is! Map) {
      throw const BackupException(
        'Uma despesa do backup possui formato inválido.',
      );
    }

    final Map<String, dynamic> row = Map<String, dynamic>.from(rawRow);

    return <String, Object?>{
      'id': _requiredString(row, 'id', 'despesa'),
      'amount': _requiredPositiveDouble(row, 'amount', 'despesa'),
      'categoryName': _requiredString(row, 'categoryName', 'despesa'),
      'description': _optionalString(row['description']),
      'notes': _optionalString(row['notes']),
      'date': _requiredDateString(row, 'date', 'despesa'),
      'paymentMethod': _optionalString(row['paymentMethod']),
      'isRecurring': _requiredBooleanInteger(row, 'isRecurring', 'despesa'),
      'recurringExpenseId': _optionalString(row['recurringExpenseId']),
      'createdAt': _requiredDateString(row, 'createdAt', 'despesa'),
      'updatedAt': _requiredDateString(row, 'updatedAt', 'despesa'),
    };
  }

  Map<String, Object?> _validateRecurringExpenseRow(dynamic rawRow) {
    if (rawRow is! Map) {
      throw const BackupException(
        'Uma despesa recorrente possui formato inválido.',
      );
    }

    final Map<String, dynamic> row = Map<String, dynamic>.from(rawRow);

    final String frequency = _requiredString(
      row,
      'frequency',
      'despesa recorrente',
    );

    const Set<String> validFrequencies = <String>{
      'weekly',
      'biweekly',
      'monthly',
      'yearly',
      'custom',
    };

    if (!validFrequencies.contains(frequency)) {
      throw const BackupException(
        'Uma despesa recorrente possui frequência inválida.',
      );
    }

    final int? customIntervalDays = _optionalPositiveInteger(
      row['customIntervalDays'],
    );

    if (frequency == 'custom' && customIntervalDays == null) {
      throw const BackupException(
        'Uma despesa recorrente personalizada está incompleta.',
      );
    }

    return <String, Object?>{
      'id': _requiredString(row, 'id', 'despesa recorrente'),
      'amount': _requiredPositiveDouble(row, 'amount', 'despesa recorrente'),
      'categoryName': _requiredString(
        row,
        'categoryName',
        'despesa recorrente',
      ),
      'description': _optionalString(row['description']),
      'notes': _optionalString(row['notes']),
      'paymentMethod': _optionalString(row['paymentMethod']),
      'frequency': frequency,
      'customIntervalDays': customIntervalDays,
      'nextDate': _requiredDateString(row, 'nextDate', 'despesa recorrente'),
      'isActive': _requiredBooleanInteger(
        row,
        'isActive',
        'despesa recorrente',
      ),
      'lastRegisteredAt': _optionalDateString(row['lastRegisteredAt']),
      'registeredCount': _requiredNonNegativeInteger(
        row,
        'registeredCount',
        'despesa recorrente',
      ),
      'createdAt': _requiredDateString(row, 'createdAt', 'despesa recorrente'),
      'updatedAt': _requiredDateString(row, 'updatedAt', 'despesa recorrente'),
    };
  }

  String _requiredString(
    Map<String, dynamic> row,
    String key,
    String recordLabel,
  ) {
    final dynamic value = row[key];

    if (value is! String || value.trim().isEmpty) {
      throw BackupException(
        'Uma $recordLabel possui o campo '
        '"$key" inválido.',
      );
    }

    return _repairTextEncoding(value);
  }

  double _requiredPositiveDouble(
    Map<String, dynamic> row,
    String key,
    String recordLabel,
  ) {
    final dynamic value = row[key];

    if (value is! num || !value.isFinite || value <= 0) {
      throw BackupException(
        'Uma $recordLabel possui o campo '
        '"$key" inválido.',
      );
    }

    return value.toDouble();
  }

  int _requiredBooleanInteger(
    Map<String, dynamic> row,
    String key,
    String recordLabel,
  ) {
    final dynamic value = row[key];

    if (value is! num) {
      throw BackupException(
        'Uma $recordLabel possui o campo '
        '"$key" inválido.',
      );
    }

    final int converted = value.toInt();

    if (converted != 0 && converted != 1) {
      throw BackupException(
        'Uma $recordLabel possui o campo '
        '"$key" inválido.',
      );
    }

    return converted;
  }

  int _requiredNonNegativeInteger(
    Map<String, dynamic> row,
    String key,
    String recordLabel,
  ) {
    final dynamic value = row[key];

    if (value is! num || value.toInt() < 0) {
      throw BackupException(
        'Uma $recordLabel possui o campo '
        '"$key" inválido.',
      );
    }

    return value.toInt();
  }

  String _requiredDateString(
    Map<String, dynamic> row,
    String key,
    String recordLabel,
  ) {
    final String value = _requiredString(row, key, recordLabel);

    if (DateTime.tryParse(value) == null) {
      throw BackupException('Uma $recordLabel possui uma data inválida.');
    }

    return value;
  }

  String _repairTextEncoding(String value) {
    final bool mayBeCorrupted =
        value.contains('Ã') || value.contains('Â') || value.contains('â');

    if (!mayBeCorrupted) {
      return value;
    }

    try {
      final String repaired = utf8.decode(
        latin1.encode(value),
        allowMalformed: false,
      );

      if (repaired.contains('\uFFFD')) {
        return value;
      }

      return repaired;
    } catch (_) {
      // Textos realmente corretos contendo esses caracteres
      // permanecem inalterados.
      return value;
    }
  }

  String? _optionalString(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw const BackupException(
        'O backup contém um campo de texto inválido.',
      );
    }

    return _repairTextEncoding(value);
  }

  String? _optionalDateString(dynamic value) {
    final String? text = _optionalString(value);

    if (text == null || text.isEmpty) {
      return null;
    }

    if (DateTime.tryParse(text) == null) {
      throw const BackupException(
        'O backup contém uma data opcional inválida.',
      );
    }

    return text;
  }

  int? _optionalPositiveInteger(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is! num || value.toInt() <= 0) {
      throw const BackupException('O backup contém um intervalo inválido.');
    }

    return value.toInt();
  }

  /// Produz uma representação estável do conteúdo antes de calcular
  /// o checksum. As chaves dos mapas são ordenadas para que a ordem
  /// interna do JSON não altere o resultado.
  String _calculatePayloadChecksum(Map<String, dynamic> payload) {
    final dynamic canonicalPayload = _canonicalizeJson(payload);

    return _calculateChecksum(jsonEncode(canonicalPayload));
  }

  /// Ordena mapas recursivamente e normaliza números inteiros
  /// que tenham sido lidos como double.
  dynamic _canonicalizeJson(dynamic value) {
    if (value is Map) {
      final List<MapEntry<String, dynamic>> entries =
          value.entries
              .map<MapEntry<String, dynamic>>((
                MapEntry<dynamic, dynamic> entry,
              ) {
                return MapEntry<String, dynamic>(
                  entry.key.toString(),
                  entry.value,
                );
              })
              .toList(growable: true)
            ..sort((
              MapEntry<String, dynamic> first,
              MapEntry<String, dynamic> second,
            ) {
              return first.key.compareTo(second.key);
            });

      return <String, dynamic>{
        for (final MapEntry<String, dynamic> entry in entries)
          entry.key: _canonicalizeJson(entry.value),
      };
    }

    if (value is List) {
      return value.map<dynamic>(_canonicalizeJson).toList(growable: false);
    }

    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }

    return value;
  }

  /// Checksum FNV-1a de 32 bits para detectar alterações
  /// acidentais ou arquivos incompletos.
  String _calculateChecksum(String content) {
    int hash = 0x811C9DC5;

    for (final int byte in utf8.encode(content)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _ValidatedBackup {
  const _ValidatedBackup({
    required this.createdAt,
    required this.expenses,
    required this.recurringExpenses,
    required this.preferences,
  });

  final DateTime createdAt;

  final List<Map<String, Object?>> expenses;

  final List<Map<String, Object?>> recurringExpenses;

  final Map<String, dynamic> preferences;
}
