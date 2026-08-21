import 'dart:math' as math;

import '../../planning/domain/monthly_financial_summary.dart';
import '../../planning/domain/monthly_plan.dart';

class MonthlyEvolutionSnapshot {
  MonthlyEvolutionSnapshot({
    required DateTime month,
    required this.incomeCents,
    required this.spentCents,
    required this.allocatedToReserveCents,
    this.spendingLimitCents,
  }) : month = DateTime(month.year, month.month);

  final DateTime month;
  final int incomeCents;
  final int spentCents;
  final int? spendingLimitCents;
  final int allocatedToReserveCents;

  String get yearMonth => MonthlyPlan.keyFor(month);

  MonthlyFinancialSummary get summary => MonthlyFinancialSummary(
    incomeTotalCents: incomeCents,
    spentCents: spentCents,
    spendingLimitCents: spendingLimitCents,
  );

  int? get resultCents => summary.currentResultCents;

  double? get savingsRate => summary.savingsRate;

  int get availableToReserveCents {
    final int? result = resultCents;
    if (result == null || result <= 0) {
      return 0;
    }

    return math.max(result - allocatedToReserveCents, 0);
  }

  bool isClosedAt(DateTime referenceMonth) {
    final DateTime normalizedReference = DateTime(
      referenceMonth.year,
      referenceMonth.month,
    );
    return month.isBefore(normalizedReference);
  }
}

class MonthlyEvolutionComparison {
  const MonthlyEvolutionComparison({
    required this.current,
    required this.previous,
  });

  final MonthlyEvolutionSnapshot current;
  final MonthlyEvolutionSnapshot previous;

  int? get resultDifferenceCents {
    final int? currentResult = current.resultCents;
    final int? previousResult = previous.resultCents;
    if (currentResult == null || previousResult == null) {
      return null;
    }
    return currentResult - previousResult;
  }

  int get spentDifferenceCents => current.spentCents - previous.spentCents;

  double? get savingsRateDifference {
    final double? currentRate = current.savingsRate;
    final double? previousRate = previous.savingsRate;
    if (currentRate == null || previousRate == null) {
      return null;
    }
    return currentRate - previousRate;
  }
}

class FinancialEvolution {
  FinancialEvolution({required List<MonthlyEvolutionSnapshot> months})
    : months = List<MonthlyEvolutionSnapshot>.unmodifiable(
        List<MonthlyEvolutionSnapshot>.from(months)..sort((
          MonthlyEvolutionSnapshot first,
          MonthlyEvolutionSnapshot second,
        ) {
          return first.month.compareTo(second.month);
        }),
      );

  final List<MonthlyEvolutionSnapshot> months;

  List<MonthlyEvolutionSnapshot> get monthsWithIncome => months
      .where((MonthlyEvolutionSnapshot month) => month.incomeCents > 0)
      .toList(growable: false);

  bool get hasAnyData => months.any(
    (MonthlyEvolutionSnapshot month) =>
        month.incomeCents > 0 ||
        month.spentCents > 0 ||
        (month.spendingLimitCents ?? 0) > 0 ||
        month.allocatedToReserveCents > 0,
  );

  int get totalIncomeCents => months.fold<int>(
    0,
    (int total, MonthlyEvolutionSnapshot month) => total + month.incomeCents,
  );

  int get totalSpentCents => months.fold<int>(
    0,
    (int total, MonthlyEvolutionSnapshot month) => total + month.spentCents,
  );

  int? get accumulatedResultCents {
    final List<MonthlyEvolutionSnapshot> eligibleMonths = monthsWithIncome;
    if (eligibleMonths.isEmpty) {
      return null;
    }
    return eligibleMonths.fold<int>(
      0,
      (int total, MonthlyEvolutionSnapshot month) => total + month.resultCents!,
    );
  }

  int? get averageResultCents {
    final int? accumulated = accumulatedResultCents;
    final int count = monthsWithIncome.length;
    if (accumulated == null || count == 0) {
      return null;
    }
    return (accumulated / count).round();
  }

  MonthlyEvolutionSnapshot? get highestResultMonth {
    final List<MonthlyEvolutionSnapshot> eligibleMonths = monthsWithIncome;
    if (eligibleMonths.isEmpty) {
      return null;
    }
    return eligibleMonths.reduce(
      (MonthlyEvolutionSnapshot first, MonthlyEvolutionSnapshot second) =>
          first.resultCents! >= second.resultCents! ? first : second,
    );
  }

  MonthlyEvolutionSnapshot? get lowestResultMonth {
    final List<MonthlyEvolutionSnapshot> eligibleMonths = monthsWithIncome;
    if (eligibleMonths.isEmpty) {
      return null;
    }
    return eligibleMonths.reduce(
      (MonthlyEvolutionSnapshot first, MonthlyEvolutionSnapshot second) =>
          first.resultCents! <= second.resultCents! ? first : second,
    );
  }

  MonthlyEvolutionComparison? comparisonFor(MonthlyEvolutionSnapshot current) {
    final int index = months.indexOf(current);
    if (index <= 0) {
      return null;
    }
    return MonthlyEvolutionComparison(
      current: current,
      previous: months[index - 1],
    );
  }
}
