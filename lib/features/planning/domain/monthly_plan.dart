class MonthlyPlan {
  const MonthlyPlan({
    required this.yearMonth,
    required this.spendingLimitCents,
    this.warningPercent = 70,
    required this.createdAt,
    required this.updatedAt,
  });

  final String yearMonth;
  final int spendingLimitCents;
  final int warningPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get spendingLimit => spendingLimitCents / 100;

  static String keyFor(DateTime month) {
    final String normalizedMonth = month.month.toString().padLeft(2, '0');
    return '${month.year}-$normalizedMonth';
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'yearMonth': yearMonth,
      'spendingLimitCents': spendingLimitCents,
      'warningPercent': warningPercent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MonthlyPlan.fromMap(Map<String, Object?> map) {
    final DateTime now = DateTime.now();

    return MonthlyPlan(
      yearMonth: map['yearMonth']?.toString() ?? '',
      spendingLimitCents: (map['spendingLimitCents'] as num?)?.toInt() ?? 0,
      warningPercent: (map['warningPercent'] as num?)?.toInt() ?? 70,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? now,
    );
  }
}
