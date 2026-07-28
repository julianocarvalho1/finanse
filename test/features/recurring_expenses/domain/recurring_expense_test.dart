import 'package:finanse/features/recurring_expenses/domain/recurring_expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurringFrequency', () {
    test('reconstrói frequências salvas no SQLite', () {
      expect(
        RecurringFrequency.fromDatabaseValue('weekly'),
        RecurringFrequency.weekly,
      );

      expect(
        RecurringFrequency.fromDatabaseValue(' BIWEEKLY '),
        RecurringFrequency.biweekly,
      );

      expect(
        RecurringFrequency.fromDatabaseValue('yearly'),
        RecurringFrequency.yearly,
      );

      expect(
        RecurringFrequency.fromDatabaseValue('custom'),
        RecurringFrequency.custom,
      );

      expect(
        RecurringFrequency.fromDatabaseValue('desconhecida'),
        RecurringFrequency.monthly,
      );

      expect(
        RecurringFrequency.fromDatabaseValue(null),
        RecurringFrequency.monthly,
      );
    });
  });

  group('RecurringExpense', () {
    test('converte a recorrência para o formato do SQLite', () {
      final RecurringExpense recurringExpense = _createRecurringExpense(
        frequency: RecurringFrequency.custom,
        customIntervalDays: 10,
        description: '  Academia  ',
        notes: '   ',
        paymentMethod: ' Pix ',
        isActive: true,
        registeredCount: 3,
        lastRegisteredAt: DateTime(2026, 7, 10, 8),
      );

      final Map<String, Object?> map = recurringExpense.toMap();

      expect(map['id'], 'recurring-1');
      expect(map['amount'], 120.50);
      expect(map['categoryName'], 'Saúde');
      expect(map['description'], 'Academia');
      expect(map['notes'], isNull);
      expect(map['paymentMethod'], 'Pix');
      expect(map['frequency'], 'custom');
      expect(map['customIntervalDays'], 10);
      expect(map['isActive'], 1);
      expect(map['registeredCount'], 3);
      expect(map['nextDate'], recurringExpense.nextDate.toIso8601String());
      expect(
        map['lastRegisteredAt'],
        DateTime(2026, 7, 10, 8).toIso8601String(),
      );
    });

    test('reconstrói uma recorrência a partir do mapa', () {
      final Map<String, Object?> map = <String, Object?>{
        'id': 'recurring-2',
        'amount': '89.90',
        'categoryName': 'Moradia',
        'description': 'Aluguel',
        'notes': '',
        'paymentMethod': 'Pix',
        'frequency': 'custom',
        'customIntervalDays': '15',
        'nextDate': '2026-08-10T09:30:00.000',
        'isActive': 0,
        'lastRegisteredAt': '2026-07-26T09:30:00.000',
        'registeredCount': '4',
        'createdAt': '2026-01-01T08:00:00.000',
        'updatedAt': '2026-07-26T09:30:00.000',
      };

      final RecurringExpense recurringExpense = RecurringExpense.fromMap(map);

      expect(recurringExpense.id, 'recurring-2');
      expect(recurringExpense.amount, 89.90);
      expect(recurringExpense.categoryName, 'Moradia');
      expect(recurringExpense.description, 'Aluguel');
      expect(recurringExpense.notes, isNull);
      expect(recurringExpense.paymentMethod, 'Pix');
      expect(recurringExpense.frequency, RecurringFrequency.custom);
      expect(recurringExpense.customIntervalDays, 15);
      expect(
        recurringExpense.nextDate,
        DateTime.parse('2026-08-10T09:30:00.000'),
      );
      expect(recurringExpense.isActive, isFalse);
      expect(recurringExpense.registeredCount, 4);
      expect(
        recurringExpense.lastRegisteredAt,
        DateTime.parse('2026-07-26T09:30:00.000'),
      );
    });

    test('calcula frequências semanal e quinzenal', () {
      final DateTime initialDate = DateTime(2026, 7, 28, 14, 30);

      final RecurringExpense weekly = _createRecurringExpense(
        frequency: RecurringFrequency.weekly,
        nextDate: initialDate,
      );

      final RecurringExpense biweekly = _createRecurringExpense(
        frequency: RecurringFrequency.biweekly,
        nextDate: initialDate,
      );

      expect(weekly.calculateNextDate(), DateTime(2026, 8, 4, 14, 30));

      expect(biweekly.calculateNextDate(), DateTime(2026, 8, 11, 14, 30));
    });

    test('limita recorrência mensal ao último dia de fevereiro', () {
      final RecurringExpense recurringExpense = _createRecurringExpense(
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 1, 31, 18, 45),
      );

      expect(
        recurringExpense.calculateNextDate(),
        DateTime(2026, 2, 28, 18, 45),
      );
    });

    test('considera 29 de fevereiro em ano bissexto', () {
      final RecurringExpense recurringExpense = _createRecurringExpense(
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2028, 1, 31, 10),
      );

      expect(recurringExpense.calculateNextDate(), DateTime(2028, 2, 29, 10));
    });

    test('limita recorrência anual após 29 de fevereiro', () {
      final RecurringExpense recurringExpense = _createRecurringExpense(
        frequency: RecurringFrequency.yearly,
        nextDate: DateTime(2028, 2, 29, 11, 15),
      );

      expect(
        recurringExpense.calculateNextDate(),
        DateTime(2029, 2, 28, 11, 15),
      );
    });

    test('calcula intervalo personalizado', () {
      final RecurringExpense recurringExpense = _createRecurringExpense(
        frequency: RecurringFrequency.custom,
        customIntervalDays: 20,
        nextDate: DateTime(2026, 7, 10, 9),
      );

      expect(recurringExpense.calculateNextDate(), DateTime(2026, 7, 30, 9));

      expect(recurringExpense.frequencyLabel, 'A cada 20 dias');
    });

    test('informa vencimento, atraso e dias restantes', () {
      final RecurringExpense recurringExpense = _createRecurringExpense(
        nextDate: DateTime(2026, 7, 20, 18),
      );

      expect(recurringExpense.isDueAt(DateTime(2026, 7, 20, 17)), isFalse);

      expect(recurringExpense.isDueAt(DateTime(2026, 7, 20, 18)), isTrue);

      expect(recurringExpense.isOverdueAt(DateTime(2026, 7, 20, 23)), isFalse);

      expect(recurringExpense.isOverdueAt(DateTime(2026, 7, 21)), isTrue);

      expect(recurringExpense.daysUntil(DateTime(2026, 7, 18, 23)), 2);

      final RecurringExpense paused = recurringExpense.copyWith(
        isActive: false,
      );

      expect(paused.isDueAt(DateTime(2026, 7, 30)), isFalse);

      expect(paused.isOverdueAt(DateTime(2026, 7, 30)), isFalse);
    });

    test('marca recorrência como registrada', () {
      final DateTime registeredAt = DateTime(2026, 7, 28, 15);

      final RecurringExpense recurringExpense = _createRecurringExpense(
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 7, 31, 8),
        registeredCount: 2,
      );

      final RecurringExpense registered = recurringExpense.markAsRegistered(
        registeredAt: registeredAt,
      );

      expect(registered.nextDate, DateTime(2026, 8, 31, 8));

      expect(registered.lastRegisteredAt, registeredAt);

      expect(registered.registeredCount, 3);
      expect(registered.updatedAt, registeredAt);
      expect(registered.id, recurringExpense.id);
    });

    test('copyWith limpa campos opcionais', () {
      final RecurringExpense original = _createRecurringExpense(
        frequency: RecurringFrequency.custom,
        customIntervalDays: 12,
        description: 'Academia',
        notes: 'Renovação',
        paymentMethod: 'Cartão',
        lastRegisteredAt: DateTime(2026, 7, 1),
      );

      final RecurringExpense changed = original.copyWith(
        frequency: RecurringFrequency.monthly,
        description: null,
        notes: null,
        paymentMethod: null,
        lastRegisteredAt: null,
      );

      expect(changed.frequency, RecurringFrequency.monthly);

      expect(changed.customIntervalDays, isNull);
      expect(changed.description, isNull);
      expect(changed.notes, isNull);
      expect(changed.paymentMethod, isNull);
      expect(changed.lastRegisteredAt, isNull);
    });
  });
}

RecurringExpense _createRecurringExpense({
  RecurringFrequency frequency = RecurringFrequency.monthly,
  int? customIntervalDays,
  DateTime? nextDate,
  String? description,
  String? notes,
  String? paymentMethod,
  bool isActive = true,
  DateTime? lastRegisteredAt,
  int registeredCount = 0,
}) {
  return RecurringExpense(
    id: 'recurring-1',
    amount: 120.50,
    categoryName: 'Saúde',
    description: description,
    notes: notes,
    paymentMethod: paymentMethod,
    frequency: frequency,
    customIntervalDays: customIntervalDays,
    nextDate: nextDate ?? DateTime(2026, 7, 28, 10),
    isActive: isActive,
    lastRegisteredAt: lastRegisteredAt,
    registeredCount: registeredCount,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 7, 1),
  );
}
