/// Frequências disponíveis para uma despesa recorrente.
enum RecurringFrequency {
  weekly(databaseValue: 'weekly', label: 'Semanal'),
  biweekly(databaseValue: 'biweekly', label: 'Quinzenal'),
  monthly(databaseValue: 'monthly', label: 'Mensal'),
  yearly(databaseValue: 'yearly', label: 'Anual'),
  custom(databaseValue: 'custom', label: 'Personalizada');

  const RecurringFrequency({required this.databaseValue, required this.label});

  final String databaseValue;
  final String label;

  /// Reconstrói a frequência usando o valor salvo no SQLite.
  static RecurringFrequency fromDatabaseValue(Object? value) {
    final String normalizedValue = value?.toString().trim().toLowerCase() ?? '';

    for (final RecurringFrequency frequency in RecurringFrequency.values) {
      if (frequency.databaseValue == normalizedValue) {
        return frequency;
      }
    }

    return RecurringFrequency.monthly;
  }
}

/// Representa uma despesa que precisa ser registrada repetidamente.
///
/// A recorrência não é um gasto do histórico por si só.
/// Ao marcá-la como registrada, um novo gasto será criado na tabela
/// `expenses` e a próxima data da recorrência será avançada.
class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.amount,
    required this.categoryName,
    this.description,
    this.notes,
    this.paymentMethod,
    required this.frequency,
    this.customIntervalDays,
    required this.nextDate,
    this.isActive = true,
    this.lastRegisteredAt,
    this.registeredCount = 0,
    this.undoExpenseId,
    this.undoPreviousNextDate,
    this.undoPreviousLastRegisteredAt,
    this.undoPreviousRegisteredCount,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(amount > 0, 'O valor da recorrência precisa ser maior que zero.'),
       assert(
         registeredCount >= 0,
         'A quantidade de registros não pode ser negativa.',
       ),
       assert(
         frequency != RecurringFrequency.custom ||
             (customIntervalDays != null && customIntervalDays > 0),
         'A frequência personalizada precisa de um intervalo válido.',
       );

  final String id;
  final double amount;
  final String categoryName;
  final String? description;
  final String? notes;
  final String? paymentMethod;

  final RecurringFrequency frequency;

  /// Quantidade de dias entre registros quando a frequência for personalizada.
  final int? customIntervalDays;

  /// Próxima data prevista para registrar essa despesa.
  final DateTime nextDate;

  /// Recorrências pausadas permanecem salvas, mas não ficam pendentes.
  final bool isActive;

  /// Data em que a recorrência foi registrada pela última vez.
  final DateTime? lastRegisteredAt;

  /// Quantidade de gastos já criados a partir dessa recorrência.
  final int registeredCount;

  /// ID do último gasto que ainda pode ser desfeito.
  final String? undoExpenseId;

  /// Próximo vencimento existente antes do último registro.
  final DateTime? undoPreviousNextDate;

  /// Data do último registro antes da operação mais recente.
  final DateTime? undoPreviousLastRegisteredAt;

  /// Quantidade de registros antes da operação mais recente.
  final int? undoPreviousRegisteredCount;

  /// Informa se existe um último registro disponível para desfazer.
  bool get canUndoLastRegistration {
    return registeredCount > 0 &&
        undoExpenseId != null &&
        undoPreviousNextDate != null &&
        undoPreviousRegisteredCount != null;
  }

  final DateTime createdAt;
  final DateTime updatedAt;

  static const Object _notProvided = Object();

  /// Informa se a recorrência já chegou à data prevista.
  bool isDueAt(DateTime referenceDate) {
    return isActive && !nextDate.isAfter(referenceDate);
  }

  /// Informa se a recorrência está atrasada em relação ao dia informado.
  bool isOverdueAt(DateTime referenceDate) {
    if (!isActive) {
      return false;
    }

    final DateTime recurrenceDay = DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
    );

    final DateTime referenceDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    return recurrenceDay.isBefore(referenceDay);
  }

  /// Quantos dias faltam para a próxima ocorrência.
  ///
  /// Um resultado negativo indica atraso.
  int daysUntil(DateTime referenceDate) {
    final DateTime recurrenceDay = DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
    );

    final DateTime referenceDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    return recurrenceDay.difference(referenceDay).inDays;
  }

  /// Descrição amigável da frequência.
  String get frequencyLabel {
    if (frequency != RecurringFrequency.custom) {
      return frequency.label;
    }

    final int days = customIntervalDays ?? 1;

    if (days == 1) {
      return 'A cada dia';
    }

    return 'A cada $days dias';
  }

  /// Calcula a próxima data da recorrência.
  ///
  /// Por padrão, utiliza a atual `nextDate` como ponto de partida.
  DateTime calculateNextDate({DateTime? from}) {
    final DateTime baseDate = from ?? nextDate;

    switch (frequency) {
      case RecurringFrequency.weekly:
        return baseDate.add(const Duration(days: 7));

      case RecurringFrequency.biweekly:
        return baseDate.add(const Duration(days: 14));

      case RecurringFrequency.monthly:
        return _addMonthsClamped(baseDate, 1);

      case RecurringFrequency.yearly:
        return _addMonthsClamped(baseDate, 12);

      case RecurringFrequency.custom:
        return baseDate.add(Duration(days: customIntervalDays ?? 1));
    }
  }

  /// Converte o modelo para o formato utilizado pelo SQLite.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'amount': amount,
      'categoryName': categoryName.trim(),
      'description': _emptyToNull(description),
      'notes': _emptyToNull(notes),
      'paymentMethod': _emptyToNull(paymentMethod),
      'frequency': frequency.databaseValue,
      'customIntervalDays': frequency == RecurringFrequency.custom
          ? customIntervalDays
          : null,
      'nextDate': nextDate.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'lastRegisteredAt': lastRegisteredAt?.toIso8601String(),
      'registeredCount': registeredCount,
      'undoExpenseId': _emptyToNull(undoExpenseId),
      'undoPreviousNextDate': undoPreviousNextDate?.toIso8601String(),
      'undoPreviousLastRegisteredAt': undoPreviousLastRegisteredAt
          ?.toIso8601String(),
      'undoPreviousRegisteredCount': undoPreviousRegisteredCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Reconstrói uma recorrência usando um registro do SQLite.
  factory RecurringExpense.fromMap(Map<String, Object?> map) {
    final DateTime now = DateTime.now();

    final RecurringFrequency parsedFrequency =
        RecurringFrequency.fromDatabaseValue(map['frequency']);

    final int? parsedCustomInterval = _parseNullableInteger(
      map['customIntervalDays'],
    );

    return RecurringExpense(
      id: map['id']?.toString() ?? '',
      amount: _parseAmount(map['amount']),
      categoryName: _parseNullableString(map['categoryName']) ?? 'Outros',
      description: _parseNullableString(map['description']),
      notes: _parseNullableString(map['notes']),
      paymentMethod: _parseNullableString(map['paymentMethod']),
      frequency: parsedFrequency,
      customIntervalDays: parsedFrequency == RecurringFrequency.custom
          ? (parsedCustomInterval ?? 1)
          : null,
      nextDate: _parseDate(map['nextDate'], fallback: now),
      isActive: _parseBoolean(map['isActive'], fallback: true),
      lastRegisteredAt: _parseNullableDate(map['lastRegisteredAt']),
      registeredCount: _parseInteger(map['registeredCount'], fallback: 0),
      undoExpenseId: _parseNullableString(map['undoExpenseId']),
      undoPreviousNextDate: _parseNullableDate(map['undoPreviousNextDate']),
      undoPreviousLastRegisteredAt: _parseNullableDate(
        map['undoPreviousLastRegisteredAt'],
      ),
      undoPreviousRegisteredCount: _parseNullableInteger(
        map['undoPreviousRegisteredCount'],
      ),
      createdAt: _parseDate(map['createdAt'], fallback: now),
      updatedAt: _parseDate(map['updatedAt'], fallback: now),
    );
  }

  /// Cria uma cópia alterando somente os campos fornecidos.
  ///
  /// Os campos opcionais utilizam um marcador interno para diferenciar:
  /// - campo não informado;
  /// - campo informado explicitamente como `null`.
  RecurringExpense copyWith({
    String? id,
    double? amount,
    String? categoryName,
    Object? description = _notProvided,
    Object? notes = _notProvided,
    Object? paymentMethod = _notProvided,
    RecurringFrequency? frequency,
    Object? customIntervalDays = _notProvided,
    DateTime? nextDate,
    bool? isActive,
    Object? lastRegisteredAt = _notProvided,
    int? registeredCount,
    Object? undoExpenseId = _notProvided,
    Object? undoPreviousNextDate = _notProvided,
    Object? undoPreviousLastRegisteredAt = _notProvided,
    Object? undoPreviousRegisteredCount = _notProvided,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final RecurringFrequency resultingFrequency = frequency ?? this.frequency;

    final int? resultingCustomInterval =
        identical(customIntervalDays, _notProvided)
        ? this.customIntervalDays
        : customIntervalDays as int?;

    return RecurringExpense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryName: categoryName ?? this.categoryName,
      description: identical(description, _notProvided)
          ? this.description
          : description as String?,
      notes: identical(notes, _notProvided) ? this.notes : notes as String?,
      paymentMethod: identical(paymentMethod, _notProvided)
          ? this.paymentMethod
          : paymentMethod as String?,
      frequency: resultingFrequency,
      customIntervalDays: resultingFrequency == RecurringFrequency.custom
          ? resultingCustomInterval
          : null,
      nextDate: nextDate ?? this.nextDate,
      isActive: isActive ?? this.isActive,
      lastRegisteredAt: identical(lastRegisteredAt, _notProvided)
          ? this.lastRegisteredAt
          : lastRegisteredAt as DateTime?,
      registeredCount: registeredCount ?? this.registeredCount,
      undoExpenseId: identical(undoExpenseId, _notProvided)
          ? this.undoExpenseId
          : undoExpenseId as String?,
      undoPreviousNextDate: identical(undoPreviousNextDate, _notProvided)
          ? this.undoPreviousNextDate
          : undoPreviousNextDate as DateTime?,
      undoPreviousLastRegisteredAt:
          identical(undoPreviousLastRegisteredAt, _notProvided)
          ? this.undoPreviousLastRegisteredAt
          : undoPreviousLastRegisteredAt as DateTime?,
      undoPreviousRegisteredCount:
          identical(undoPreviousRegisteredCount, _notProvided)
          ? this.undoPreviousRegisteredCount
          : undoPreviousRegisteredCount as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Cria uma cópia representando a recorrência após um registro concluído.
  RecurringExpense markAsRegistered({
    required DateTime registeredAt,
    required String expenseId,
  }) {
    return copyWith(
      nextDate: calculateNextDate(),
      lastRegisteredAt: registeredAt,
      registeredCount: registeredCount + 1,
      undoExpenseId: expenseId,
      undoPreviousNextDate: nextDate,
      undoPreviousLastRegisteredAt: lastRegisteredAt,
      undoPreviousRegisteredCount: registeredCount,
      updatedAt: registeredAt,
    );
  }

  /// Adiciona meses preservando o horário e limitando o dia ao último dia
  /// disponível no mês de destino.
  ///
  /// Exemplo:
  /// 31 de janeiro + 1 mês = último dia de fevereiro.
  static DateTime _addMonthsClamped(DateTime date, int months) {
    final int totalMonths = (date.year * 12) + (date.month - 1) + months;

    final int targetYear = totalMonths ~/ 12;
    final int targetMonth = (totalMonths % 12) + 1;

    final int lastDayOfTargetMonth = DateTime(
      targetYear,
      targetMonth + 1,
      0,
    ).day;

    final int targetDay = date.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : date.day;

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static double _parseAmount(Object? value) {
    if (value is num) {
      final double parsedValue = value.toDouble();

      return parsedValue > 0 ? parsedValue : 0.01;
    }

    final double parsedValue = double.tryParse(value?.toString() ?? '') ?? 0.01;

    return parsedValue > 0 ? parsedValue : 0.01;
  }

  static int _parseInteger(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _parseNullableInteger(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static bool _parseBoolean(Object? value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalizedValue = value?.toString().trim().toLowerCase() ?? '';

    if (normalizedValue == 'true' ||
        normalizedValue == '1' ||
        normalizedValue == 'yes') {
      return true;
    }

    if (normalizedValue == 'false' ||
        normalizedValue == '0' ||
        normalizedValue == 'no') {
      return false;
    }

    return fallback;
  }

  static DateTime _parseDate(Object? value, {required DateTime fallback}) {
    return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static String? _parseNullableString(Object? value) {
    final String? normalizedValue = value?.toString().trim();

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }

  static String? _emptyToNull(String? value) {
    final String? normalizedValue = value?.trim();

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }
}
