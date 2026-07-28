import 'package:finanse/features/recurring_expenses/data/recurring_notification_scheduler.dart';
import 'package:finanse/features/recurring_expenses/domain/recurring_expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finanse/features/recurring_expenses/data/recurring_expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRecurringNotificationService notificationService;
  late DateTime fixedNow;
  late RecurringNotificationScheduler scheduler;

  setUp(() {
    fixedNow = DateTime(2026, 7, 28, 10);

    SharedPreferences.setMockInitialValues(<String, Object>{
      RecurringNotificationScheduler.notificationsEnabledKey: true,
    });

    notificationService = _FakeRecurringNotificationService(
      permissionAllowed: true,
    );

    scheduler = RecurringNotificationScheduler(
      notificationService: notificationService,
      nowProvider: () => fixedNow,
    );
  });

  group('RecurringNotificationScheduler', () {
    test('agenda uma recorrência ativa com data futura', () async {
      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-notification-1',
        amount: 149.90,
        categoryName: 'Assinaturas',
        description: 'Internet',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 10, 9),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

      final bool scheduled = await scheduler.synchronizeRecurringExpense(
        recurringExpense,
      );

      expect(scheduled, isTrue);
      expect(notificationService.initializeCount, 1);
      expect(notificationService.permissionCheckCount, 1);
      expect(notificationService.scheduleCount, 1);
      expect(notificationService.cancelledIds, isEmpty);

      expect(notificationService.lastRecurringExpenseId, recurringExpense.id);

      expect(notificationService.lastCategoryName, 'Assinaturas');

      expect(notificationService.lastAmount, 149.90);

      expect(notificationService.lastScheduledDate, DateTime(2026, 8, 10, 9));

      expect(notificationService.lastDescription, 'Internet');
    });

    test(
      'cancela o lembrete quando as notificações estão desativadas',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          RecurringNotificationScheduler.notificationsEnabledKey: false,
        });

        final RecurringExpense recurringExpense = RecurringExpense(
          id: 'recurring-notification-disabled-1',
          amount: 89.90,
          categoryName: 'Assinaturas',
          description: 'Streaming',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 15, 9),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        );

        final bool scheduled = await scheduler.synchronizeRecurringExpense(
          recurringExpense,
        );

        expect(scheduled, isFalse);
        expect(notificationService.scheduleCount, 0);
        expect(notificationService.permissionCheckCount, 0);

        expect(notificationService.cancelledIds, <String>[recurringExpense.id]);
      },
    );

    test('cancela o lembrete quando o sistema nega a permissão', () async {
      notificationService = _FakeRecurringNotificationService(
        permissionAllowed: false,
      );

      scheduler = RecurringNotificationScheduler(
        notificationService: notificationService,
        nowProvider: () => fixedNow,
      );

      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-permission-denied-1',
        amount: 59.90,
        categoryName: 'Assinaturas',
        description: 'Aplicativo',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 20, 9),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

      final bool scheduled = await scheduler.synchronizeRecurringExpense(
        recurringExpense,
      );

      expect(scheduled, isFalse);
      expect(notificationService.permissionCheckCount, 1);
      expect(notificationService.scheduleCount, 0);

      expect(notificationService.cancelledIds, <String>[recurringExpense.id]);

      expect(notificationService.initializeCount, 2);
    });

    test('cancela o lembrete de uma recorrência pausada', () async {
      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-paused-notification-1',
        amount: 120,
        categoryName: 'Saúde',
        description: 'Academia',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 8, 10, 9),
        isActive: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

      final bool scheduled = await scheduler.synchronizeRecurringExpense(
        recurringExpense,
      );

      expect(scheduled, isFalse);
      expect(notificationService.permissionCheckCount, 1);
      expect(notificationService.scheduleCount, 0);

      expect(notificationService.cancelledIds, <String>[recurringExpense.id]);

      expect(notificationService.initializeCount, 2);
    });

    test('cancela o lembrete quando a data da recorrência já chegou', () async {
      final RecurringExpense recurringExpense = RecurringExpense(
        id: 'recurring-due-notification-1',
        amount: 210,
        categoryName: 'Contas',
        description: 'Conta de energia',
        frequency: RecurringFrequency.monthly,
        nextDate: fixedNow,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

      final bool scheduled = await scheduler.synchronizeRecurringExpense(
        recurringExpense,
      );

      expect(scheduled, isFalse);
      expect(notificationService.permissionCheckCount, 1);
      expect(notificationService.scheduleCount, 0);

      expect(notificationService.cancelledIds, <String>[recurringExpense.id]);

      expect(notificationService.initializeCount, 2);
    });

    test('cancela todos os lembretes futuros', () async {
      await scheduler.cancelAllScheduledNotifications();

      expect(notificationService.initializeCount, 1);
      expect(notificationService.cancelAllCount, 1);
      expect(notificationService.scheduleCount, 0);
      expect(notificationService.cancelledIds, isEmpty);
    });
    test('sincroniza todas as recorrências salvas', () async {
      final List<RecurringExpense> recurringExpenses = <RecurringExpense>[
        RecurringExpense(
          id: 'recurring-all-future',
          amount: 150,
          categoryName: 'Assinaturas',
          description: 'Recorrência futura',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 10, 9),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
        RecurringExpense(
          id: 'recurring-all-paused',
          amount: 90,
          categoryName: 'Saúde',
          description: 'Recorrência pausada',
          frequency: RecurringFrequency.monthly,
          nextDate: DateTime(2026, 8, 15, 9),
          isActive: false,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
        RecurringExpense(
          id: 'recurring-all-due',
          amount: 70,
          categoryName: 'Contas',
          description: 'Recorrência vencida',
          frequency: RecurringFrequency.monthly,
          nextDate: fixedNow,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      ];

      final _FakeRecurringExpenseRepository repository =
          _FakeRecurringExpenseRepository(recurringExpenses);

      scheduler = RecurringNotificationScheduler(
        notificationService: notificationService,
        repository: repository,
        nowProvider: () => fixedNow,
      );

      final RecurringNotificationSyncResult result = await scheduler
          .synchronizeAllRecurringExpenses();

      expect(result.scheduledCount, 1);
      expect(result.cancelledCount, 2);
      expect(result.notificationsEnabled, isTrue);
      expect(result.permissionAllowed, isTrue);

      expect(notificationService.scheduleCount, 1);
      expect(
        notificationService.lastRecurringExpenseId,
        'recurring-all-future',
      );

      expect(notificationService.cancelledIds, <String>[
        'recurring-all-paused',
        'recurring-all-due',
      ]);

      expect(notificationService.permissionCheckCount, 1);
      expect(notificationService.initializeCount, 3);
    });
  });
}

class _FakeRecurringNotificationService
    implements RecurringNotificationService {
  _FakeRecurringNotificationService({required this.permissionAllowed});

  final bool permissionAllowed;

  int initializeCount = 0;
  int permissionCheckCount = 0;
  int scheduleCount = 0;
  int cancelAllCount = 0;

  final List<String> cancelledIds = <String>[];

  String? lastRecurringExpenseId;
  String? lastCategoryName;
  double? lastAmount;
  DateTime? lastScheduledDate;
  String? lastDescription;

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<bool> areNotificationsAllowed() async {
    permissionCheckCount++;

    return permissionAllowed;
  }

  @override
  Future<void> scheduleRecurringExpenseReminder({
    required String recurringExpenseId,
    required String categoryName,
    required double amount,
    required DateTime scheduledDate,
    String? description,
  }) async {
    scheduleCount++;

    lastRecurringExpenseId = recurringExpenseId;
    lastCategoryName = categoryName;
    lastAmount = amount;
    lastScheduledDate = scheduledDate;
    lastDescription = description;
  }

  @override
  Future<void> cancelRecurringExpenseReminder(String recurringExpenseId) async {
    cancelledIds.add(recurringExpenseId);
  }

  @override
  Future<void> cancelAllScheduledNotifications() async {
    cancelAllCount++;
  }
}

class _FakeRecurringExpenseRepository extends RecurringExpenseRepository {
  _FakeRecurringExpenseRepository(this.recurringExpenses);

  final List<RecurringExpense> recurringExpenses;

  @override
  Future<List<RecurringExpense>> getAllRecurringExpenses({
    bool includePaused = true,
  }) async {
    return recurringExpenses;
  }
}
