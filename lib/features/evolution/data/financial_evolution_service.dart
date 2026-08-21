import '../../expenses/data/expense_repository.dart';
import '../../incomes/data/income_repository.dart';
import '../../planning/data/monthly_plan_repository.dart';
import '../../reserve/data/reserve_repository.dart';
import '../domain/financial_evolution.dart';

class FinancialEvolutionService {
  FinancialEvolutionService({
    IncomeRepository? incomeRepository,
    MonthlyPlanRepository? planRepository,
    ExpenseRepository? expenseRepository,
    ReserveRepository? reserveRepository,
  }) : _incomeRepository = incomeRepository ?? IncomeRepository(),
       _planRepository = planRepository ?? MonthlyPlanRepository(),
       _expenseRepository = expenseRepository ?? ExpenseRepository(),
       _reserveRepository = reserveRepository ?? ReserveRepository();

  final IncomeRepository _incomeRepository;
  final MonthlyPlanRepository _planRepository;
  final ExpenseRepository _expenseRepository;
  final ReserveRepository _reserveRepository;

  Future<FinancialEvolution> load({
    required DateTime referenceMonth,
    required int monthCount,
  }) async {
    if (monthCount <= 0) {
      throw ArgumentError.value(
        monthCount,
        'monthCount',
        'Use pelo menos um mês.',
      );
    }

    final DateTime normalizedReference = DateTime(
      referenceMonth.year,
      referenceMonth.month,
    );
    final List<MonthlyEvolutionSnapshot> snapshots =
        <MonthlyEvolutionSnapshot>[];

    for (int offset = monthCount - 1; offset >= 0; offset--) {
      final DateTime month = DateTime(
        normalizedReference.year,
        normalizedReference.month - offset,
      );
      final DateTime nextMonth = DateTime(month.year, month.month + 1);

      final int incomeCents = await _incomeRepository.getTotalCentsForMonth(
        month,
      );
      final plan = await _planRepository.getPlanForMonth(month);
      final double spent = await _expenseRepository.getTotalBetween(
        start: month,
        endExclusive: nextMonth,
      );
      final int
      allocatedToReserveCents = await _reserveRepository.getAllocatedCentsForMonth(
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
      );

      snapshots.add(
        MonthlyEvolutionSnapshot(
          month: month,
          incomeCents: incomeCents,
          spentCents: (spent * 100).round(),
          spendingLimitCents: plan?.spendingLimitCents,
          allocatedToReserveCents: allocatedToReserveCents,
        ),
      );
    }

    return FinancialEvolution(months: snapshots);
  }
}
