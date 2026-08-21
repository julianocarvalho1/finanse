enum IncomeRecurrence { none, monthly }

class Income {
  const Income({
    required this.id,
    required this.amountCents,
    required this.source,
    required this.date,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int amountCents;
  final String source;
  final DateTime date;
  final IncomeRecurrence recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get amount => amountCents / 100;

  bool occursInMonth(DateTime month) {
    final int selectedMonth = month.year * 12 + month.month;
    final int firstMonth = date.year * 12 + date.month;

    return recurrence == IncomeRecurrence.monthly
        ? selectedMonth >= firstMonth
        : selectedMonth == firstMonth;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'amountCents': amountCents,
      'source': source.trim(),
      'date': date.toIso8601String(),
      'recurrence': recurrence.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Income.fromMap(Map<String, Object?> map) {
    final DateTime now = DateTime.now();

    return Income(
      id: map['id']?.toString() ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      source: map['source']?.toString().trim() ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? now,
      recurrence: IncomeRecurrence.values.firstWhere(
        (IncomeRecurrence value) => value.name == map['recurrence'],
        orElse: () => IncomeRecurrence.none,
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  Income copyWith({
    int? amountCents,
    String? source,
    DateTime? date,
    IncomeRecurrence? recurrence,
    DateTime? updatedAt,
  }) {
    return Income(
      id: id,
      amountCents: amountCents ?? this.amountCents,
      source: source ?? this.source,
      date: date ?? this.date,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
