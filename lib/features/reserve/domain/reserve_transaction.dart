enum ReserveTransactionType { add, withdraw, adjust }

class ReserveTransaction {
  const ReserveTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.previousBalance,
    required this.balanceAfter,
    required this.createdAt,
    this.note,
    this.originYearMonth,
  });

  final String id;
  final ReserveTransactionType type;
  final double amount;
  final double previousBalance;
  final double balanceAfter;
  final DateTime createdAt;
  final String? note;
  final String? originYearMonth;

  double get signedChange => balanceAfter - previousBalance;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'amount': amount,
      'previousBalance': previousBalance,
      'balanceAfter': balanceAfter,
      'note': note,
      'originYearMonth': originYearMonth,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReserveTransaction.fromMap(Map<String, Object?> map) {
    return ReserveTransaction(
      id: map['id']! as String,
      type: ReserveTransactionType.values.firstWhere(
        (ReserveTransactionType value) => value.name == map['type'],
        orElse: () => ReserveTransactionType.adjust,
      ),
      amount: (map['amount']! as num).toDouble(),
      previousBalance: (map['previousBalance']! as num).toDouble(),
      balanceAfter: (map['balanceAfter']! as num).toDouble(),
      note: (map['note'] as String?)?.trim(),
      originYearMonth: (map['originYearMonth'] as String?)?.trim(),
      createdAt: DateTime.parse(map['createdAt']! as String),
    );
  }
}
