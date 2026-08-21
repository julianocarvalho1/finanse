import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expense', () {
    test('converte a despesa para o formato do SQLite', () {
      final DateTime expenseDate = DateTime(2026, 7, 28, 12, 30);

      final DateTime createdAt = DateTime(2026, 7, 28, 12);

      final DateTime updatedAt = DateTime(2026, 7, 28, 13);

      final Expense expense = Expense(
        id: 'expense-1',
        amount: 125.50,
        categoryName: 'Alimentação',
        description: '  Almoço  ',
        notes: '   ',
        date: expenseDate,
        paymentMethod: ' Pix ',
        isRecurring: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final Map<String, Object?> map = expense.toMap();

      expect(map['id'], 'expense-1');
      expect(map['amount'], 125.50);
      expect(map['categoryName'], 'Alimentação');
      expect(map['description'], 'Almoço');
      expect(map['notes'], isNull);
      expect(map['date'], expenseDate.toIso8601String());
      expect(map['paymentMethod'], 'Pix');
      expect(map['isRecurring'], 1);
      expect(map['createdAt'], createdAt.toIso8601String());
      expect(map['updatedAt'], updatedAt.toIso8601String());
    });

    test('reconstrói uma despesa a partir do mapa', () {
      final Map<String, Object?> map = <String, Object?>{
        'id': 'expense-2',
        'amount': '89.90',
        'categoryName': 'Transporte',
        'description': 'Combustível',
        'notes': '',
        'date': '2026-07-20T08:15:00.000',
        'paymentMethod': 'Cartão de crédito',
        'isRecurring': 1,
        'createdAt': '2026-07-20T08:00:00.000',
        'updatedAt': '2026-07-20T08:30:00.000',
      };

      final Expense expense = Expense.fromMap(map);

      expect(expense.id, 'expense-2');
      expect(expense.amount, 89.90);
      expect(expense.categoryName, 'Transporte');
      expect(expense.description, 'Combustível');
      expect(expense.notes, isNull);
      expect(expense.date, DateTime.parse('2026-07-20T08:15:00.000'));
      expect(expense.paymentMethod, 'Cartão de crédito');
      expect(expense.isRecurring, isTrue);
      expect(expense.createdAt, DateTime.parse('2026-07-20T08:00:00.000'));
      expect(expense.updatedAt, DateTime.parse('2026-07-20T08:30:00.000'));
    });

    test('copyWith altera e limpa campos opcionais', () {
      final DateTime originalDate = DateTime(2026, 7, 10);

      final DateTime creationDate = DateTime(2026, 7, 1);

      final Expense original = Expense(
        id: 'expense-3',
        amount: 50,
        categoryName: 'Lazer',
        description: 'Cinema',
        notes: 'Sessão noturna',
        date: originalDate,
        paymentMethod: 'Dinheiro',
        createdAt: creationDate,
        updatedAt: creationDate,
      );

      final Expense changed = original.copyWith(
        amount: 75,
        categoryName: 'Compras',
        description: null,
        notes: null,
        paymentMethod: null,
        updatedAt: DateTime(2026, 7, 11),
      );

      expect(changed.id, original.id);
      expect(changed.amount, 75);
      expect(changed.categoryName, 'Compras');
      expect(changed.description, isNull);
      expect(changed.notes, isNull);
      expect(changed.paymentMethod, isNull);
      expect(changed.date, originalDate);
      expect(changed.createdAt, creationDate);
      expect(changed.updatedAt, DateTime(2026, 7, 11));
    });
  });
}
