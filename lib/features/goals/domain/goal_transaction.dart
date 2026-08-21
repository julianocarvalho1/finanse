enum GoalTransactionType { allocation, withdrawal, adjustment }

class GoalTransaction {
  const GoalTransaction({
    required this.id,
    required this.goalId,
    required this.type,
    required this.changeCents,
    required this.balanceAfterCents,
    required this.createdAt,
    this.originYearMonth,
    this.note,
  });

  final String id;
  final String goalId;
  final GoalTransactionType type;
  final int changeCents;
  final int balanceAfterCents;
  final String? originYearMonth;
  final String? note;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'goalId': goalId,
      'type': type.name,
      'changeCents': changeCents,
      'balanceAfterCents': balanceAfterCents,
      'originYearMonth': originYearMonth,
      'note': note?.trim().isEmpty ?? true ? null : note?.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GoalTransaction.fromMap(Map<String, Object?> map) {
    return GoalTransaction(
      id: map['id']?.toString() ?? '',
      goalId: map['goalId']?.toString() ?? '',
      type: GoalTransactionType.values.firstWhere(
        (GoalTransactionType value) => value.name == map['type'],
        orElse: () => GoalTransactionType.adjustment,
      ),
      changeCents: (map['changeCents'] as num?)?.toInt() ?? 0,
      balanceAfterCents: (map['balanceAfterCents'] as num?)?.toInt() ?? 0,
      originYearMonth: _nullableText(map['originYearMonth']),
      note: _nullableText(map['note']),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static String? _nullableText(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
