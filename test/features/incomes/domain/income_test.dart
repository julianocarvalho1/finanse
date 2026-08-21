import 'package:finanse/features/incomes/domain/income.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renda única pertence somente ao mês cadastrado', () {
    final Income income = _income(recurrence: IncomeRecurrence.none);

    expect(income.occursInMonth(DateTime(2026, 8)), isTrue);
    expect(income.occursInMonth(DateTime(2026, 9)), isFalse);
  });

  test('renda mensal se repete a partir do mês inicial', () {
    final Income income = _income(recurrence: IncomeRecurrence.monthly);

    expect(income.occursInMonth(DateTime(2026, 7)), isFalse);
    expect(income.occursInMonth(DateTime(2026, 8)), isTrue);
    expect(income.occursInMonth(DateTime(2027, 1)), isTrue);
  });

  test('converte renda para o banco preservando centavos', () {
    final Income income = _income(recurrence: IncomeRecurrence.monthly);
    final Income restored = Income.fromMap(income.toMap());

    expect(restored.amountCents, 500012);
    expect(restored.amount, 5000.12);
    expect(restored.source, 'Salário');
    expect(restored.recurrence, IncomeRecurrence.monthly);
  });
}

Income _income({required IncomeRecurrence recurrence}) {
  final DateTime now = DateTime(2026, 8, 10);
  return Income(
    id: 'income-1',
    amountCents: 500012,
    source: 'Salário',
    date: now,
    recurrence: recurrence,
    createdAt: now,
    updatedAt: now,
  );
}
