import 'package:finanse/features/planning/domain/monthly_financial_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcula o exemplo de renda 5 mil e limite 2 mil', () {
    const MonthlyFinancialSummary summary = MonthlyFinancialSummary(
      incomeTotalCents: 500000,
      spendingLimitCents: 200000,
      spentCents: 180000,
    );

    expect(summary.availableWithinLimitCents, 20000);
    expect(summary.overLimitCents, 0);
    expect(summary.plannedSurplusCents, 300000);
    expect(summary.currentResultCents, 320000);
    expect(summary.savingsRate, closeTo(0.64, 0.0001));
    expect(summary.status, MonthlyFinancialStatus.attention);
  });

  test('mostra estado positivo quando o limite está confortável', () {
    const MonthlyFinancialSummary summary = MonthlyFinancialSummary(
      incomeTotalCents: 500000,
      spendingLimitCents: 200000,
      spentCents: 50000,
    );

    expect(summary.status, MonthlyFinancialStatus.positive);
  });

  test('não esconde déficit nem excesso do limite', () {
    const MonthlyFinancialSummary summary = MonthlyFinancialSummary(
      incomeTotalCents: 100000,
      spendingLimitCents: 80000,
      spentCents: 120000,
    );

    expect(summary.availableWithinLimitCents, 0);
    expect(summary.overLimitCents, 40000);
    expect(summary.currentResultCents, -20000);
    expect(summary.status, MonthlyFinancialStatus.deficit);
  });

  test('funciona sem renda cadastrada', () {
    const MonthlyFinancialSummary summary = MonthlyFinancialSummary(
      incomeTotalCents: 0,
      spendingLimitCents: 200000,
      spentCents: 50000,
    );

    expect(summary.availableWithinLimitCents, 150000);
    expect(summary.currentResultCents, isNull);
    expect(summary.plannedSurplusCents, isNull);
    expect(summary.status, MonthlyFinancialStatus.neutral);
  });

  test('respeita o percentual de alerta configurado', () {
    const MonthlyFinancialSummary summary = MonthlyFinancialSummary(
      incomeTotalCents: 500000,
      spentCents: 150000,
      spendingLimitCents: 200000,
      warningPercent: 80,
    );

    expect(summary.status, MonthlyFinancialStatus.positive);
  });
}
