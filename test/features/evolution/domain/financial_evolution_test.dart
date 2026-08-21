import 'package:finanse/features/evolution/domain/financial_evolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calcula acumulado, média e extremos sem ocultar resultado negativo',
    () {
      final FinancialEvolution evolution = FinancialEvolution(
        months: <MonthlyEvolutionSnapshot>[
          _snapshot(month: DateTime(2026, 6), income: 500000, spent: 180000),
          _snapshot(month: DateTime(2026, 7), income: 500000, spent: 220000),
          _snapshot(month: DateTime(2026, 8), income: 100000, spent: 130000),
        ],
      );

      expect(evolution.accumulatedResultCents, 570000);
      expect(evolution.averageResultCents, 190000);
      expect(evolution.highestResultMonth?.month, DateTime(2026, 6));
      expect(evolution.lowestResultMonth?.month, DateTime(2026, 8));
      expect(evolution.lowestResultMonth?.resultCents, -30000);
    },
  );

  test('não inventa resultado para mês sem renda cadastrada', () {
    final MonthlyEvolutionSnapshot withoutIncome = _snapshot(
      month: DateTime(2026, 7),
      income: 0,
      spent: 80000,
    );
    final FinancialEvolution evolution = FinancialEvolution(
      months: <MonthlyEvolutionSnapshot>[
        withoutIncome,
        _snapshot(month: DateTime(2026, 8), income: 500000, spent: 200000),
      ],
    );

    expect(withoutIncome.resultCents, isNull);
    expect(evolution.accumulatedResultCents, 300000);
    expect(evolution.averageResultCents, 300000);
  });

  test('compara o resultado com o mês imediatamente anterior', () {
    final MonthlyEvolutionSnapshot july = _snapshot(
      month: DateTime(2026, 7),
      income: 500000,
      spent: 250000,
    );
    final MonthlyEvolutionSnapshot august = _snapshot(
      month: DateTime(2026, 8),
      income: 500000,
      spent: 180000,
    );
    final FinancialEvolution evolution = FinancialEvolution(
      months: <MonthlyEvolutionSnapshot>[august, july],
    );

    final MonthlyEvolutionComparison comparison = evolution.comparisonFor(
      evolution.months.last,
    )!;
    expect(comparison.resultDifferenceCents, 70000);
    expect(comparison.spentDifferenceCents, -70000);
    expect(comparison.savingsRateDifference, closeTo(0.14, 0.0001));
  });

  test('desconta apenas destinações vinculadas do valor ainda disponível', () {
    final MonthlyEvolutionSnapshot snapshot = _snapshot(
      month: DateTime(2026, 8),
      income: 500000,
      spent: 180000,
      allocated: 120000,
      allocatedToGoals: 50000,
    );

    expect(snapshot.resultCents, 320000);
    expect(snapshot.availableToReserveCents, 150000);
  });
}

MonthlyEvolutionSnapshot _snapshot({
  required DateTime month,
  required int income,
  required int spent,
  int allocated = 0,
  int allocatedToGoals = 0,
}) {
  return MonthlyEvolutionSnapshot(
    month: month,
    incomeCents: income,
    spentCents: spent,
    spendingLimitCents: 200000,
    allocatedToReserveCents: allocated,
    allocatedToGoalsCents: allocatedToGoals,
  );
}
