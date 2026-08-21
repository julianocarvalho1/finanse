import 'dart:math' as math;

enum MonthlyFinancialStatus {
  neutral,
  positive,
  attention,
  limitExceeded,
  deficit,
}

class MonthlyFinancialSummary {
  const MonthlyFinancialSummary({
    required this.incomeTotalCents,
    required this.spentCents,
    this.spendingLimitCents,
  });

  final int incomeTotalCents;
  final int spentCents;
  final int? spendingLimitCents;

  bool get hasIncome => incomeTotalCents > 0;
  bool get hasLimit => (spendingLimitCents ?? 0) > 0;

  int? get availableWithinLimitCents =>
      hasLimit ? math.max(spendingLimitCents! - spentCents, 0) : null;

  int get overLimitCents =>
      hasLimit ? math.max(spentCents - spendingLimitCents!, 0) : 0;

  int? get plannedSurplusCents =>
      hasIncome && hasLimit ? incomeTotalCents - spendingLimitCents! : null;

  int? get currentResultCents =>
      hasIncome ? incomeTotalCents - spentCents : null;

  double? get savingsRate =>
      hasIncome ? (incomeTotalCents - spentCents) / incomeTotalCents : null;

  MonthlyFinancialStatus get status {
    final int? result = currentResultCents;
    if (result != null && result < 0) {
      return MonthlyFinancialStatus.deficit;
    }
    if (overLimitCents > 0) {
      return MonthlyFinancialStatus.limitExceeded;
    }
    if (hasLimit && spentCents / spendingLimitCents! >= 0.7) {
      return MonthlyFinancialStatus.attention;
    }
    if (result != null && result >= 0) {
      return MonthlyFinancialStatus.positive;
    }
    return MonthlyFinancialStatus.neutral;
  }
}
