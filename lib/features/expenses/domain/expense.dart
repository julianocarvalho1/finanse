class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.categoryName,
    this.description,
    this.notes,
    required this.date,
    this.paymentMethod,
    this.isRecurring = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final double amount;
  final String categoryName;
  final String? description;
  final String? notes;
  final DateTime date;
  final String? paymentMethod;
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const Object _notProvided = Object();

  /// Converte a despesa para o formato salvo no SQLite.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'amount': amount,
      'categoryName': categoryName,
      'description': _emptyToNull(description),
      'notes': _emptyToNull(notes),
      'date': date.toIso8601String(),
      'paymentMethod': _emptyToNull(paymentMethod),
      'isRecurring': isRecurring ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Reconstrói uma despesa a partir de um registro do SQLite.
  factory Expense.fromMap(Map<String, Object?> map) {
    final DateTime parsedDate = _parseDate(
      map['date'],
      fallback: DateTime.now(),
    );

    final DateTime parsedCreatedAt = _parseDate(
      map['createdAt'],
      fallback: parsedDate,
    );

    return Expense(
      id: map['id']?.toString() ?? '',
      amount: _parseAmount(map['amount']),
      categoryName: map['categoryName']?.toString() ?? 'Outros',
      description: _parseNullableString(map['description']),
      notes: _parseNullableString(map['notes']),
      date: parsedDate,
      paymentMethod: _parseNullableString(map['paymentMethod']),
      isRecurring: _parseBoolean(map['isRecurring']),
      createdAt: parsedCreatedAt,
      updatedAt: _parseDate(map['updatedAt'], fallback: parsedCreatedAt),
    );
  }

  /// Cria uma cópia alterando somente os campos informados.
  ///
  /// Os campos opcionais aceitam `null` para serem apagados.
  Expense copyWith({
    String? id,
    double? amount,
    String? categoryName,
    Object? description = _notProvided,
    Object? notes = _notProvided,
    DateTime? date,
    Object? paymentMethod = _notProvided,
    bool? isRecurring,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryName: categoryName ?? this.categoryName,
      description: identical(description, _notProvided)
          ? this.description
          : description as String?,
      notes: identical(notes, _notProvided) ? this.notes : notes as String?,
      date: date ?? this.date,
      paymentMethod: identical(paymentMethod, _notProvided)
          ? this.paymentMethod
          : paymentMethod as String?,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _parseAmount(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBoolean(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalizedValue = value?.toString().trim().toLowerCase() ?? '';

    return normalizedValue == 'true' ||
        normalizedValue == '1' ||
        normalizedValue == 'yes';
  }

  static DateTime _parseDate(Object? value, {required DateTime fallback}) {
    return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _parseNullableString(Object? value) {
    final String? text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static String? _emptyToNull(String? value) {
    final String? normalizedValue = value?.trim();

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }
}
