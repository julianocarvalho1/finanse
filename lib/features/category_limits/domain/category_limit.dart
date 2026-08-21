class CategoryLimit {
  const CategoryLimit({
    required this.yearMonth,
    required this.categoryName,
    required this.limitCents,
    required this.warningPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String yearMonth;
  final String categoryName;
  final int limitCents;
  final int warningPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'yearMonth': yearMonth,
      'categoryName': categoryName.trim(),
      'limitCents': limitCents,
      'warningPercent': warningPercent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CategoryLimit.fromMap(Map<String, Object?> map) {
    final DateTime now = DateTime.now();
    return CategoryLimit(
      yearMonth: map['yearMonth']?.toString() ?? '',
      categoryName: map['categoryName']?.toString().trim() ?? '',
      limitCents: (map['limitCents'] as num?)?.toInt() ?? 0,
      warningPercent: (map['warningPercent'] as num?)?.toInt() ?? 70,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? now,
    );
  }
}

enum CategoryLimitStatus { unconfigured, comfortable, attention, exceeded }

class CategoryLimitSummary {
  const CategoryLimitSummary({
    required this.categoryName,
    required this.spentCents,
    required this.previousSpentCents,
    this.limit,
  });

  final String categoryName;
  final int spentCents;
  final int previousSpentCents;
  final CategoryLimit? limit;

  int get differenceCents => spentCents - previousSpentCents;

  double? get progress => limit == null ? null : spentCents / limit!.limitCents;

  int? get availableCents => limit == null
      ? null
      : (limit!.limitCents - spentCents).clamp(0, limit!.limitCents);

  CategoryLimitStatus get status {
    final CategoryLimit? configuredLimit = limit;
    if (configuredLimit == null) {
      return CategoryLimitStatus.unconfigured;
    }
    if (spentCents > configuredLimit.limitCents) {
      return CategoryLimitStatus.exceeded;
    }
    if (spentCents / configuredLimit.limitCents >=
        configuredLimit.warningPercent / 100) {
      return CategoryLimitStatus.attention;
    }
    return CategoryLimitStatus.comfortable;
  }
}
