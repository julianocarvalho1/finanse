import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notification_service.dart';
import '../domain/recurring_expense.dart';
import 'recurring_expense_repository.dart';

/// Resultado da sincronização dos lembretes de recorrências.
class RecurringNotificationSyncResult {
  const RecurringNotificationSyncResult({
    required this.scheduledCount,
    required this.cancelledCount,
    required this.notificationsEnabled,
    required this.permissionAllowed,
  });

  /// Quantidade de lembretes que ficaram agendados.
  final int scheduledCount;

  /// Quantidade de recorrências cujo lembrete foi cancelado.
  final int cancelledCount;

  /// Preferência salva pelo usuário no aplicativo.
  final bool notificationsEnabled;

  /// Permissão concedida pelo sistema operacional.
  final bool permissionAllowed;
}

abstract interface class RecurringNotificationService {
  Future<void> initialize();

  Future<bool> areNotificationsAllowed();

  Future<void> scheduleRecurringExpenseReminder({
    required String recurringExpenseId,
    required String categoryName,
    required double amount,
    required DateTime scheduledDate,
    String? description,
  });

  Future<void> cancelRecurringExpenseReminder(String recurringExpenseId);

  Future<void> cancelAllScheduledNotifications();
}

class _NotificationServiceAdapter implements RecurringNotificationService {
  _NotificationServiceAdapter({NotificationService? notificationService})
    : _notificationService =
          notificationService ?? NotificationService.instance;

  final NotificationService _notificationService;

  @override
  Future<void> initialize() {
    return _notificationService.initialize();
  }

  @override
  Future<bool> areNotificationsAllowed() {
    return _notificationService.areNotificationsAllowed();
  }

  @override
  Future<void> scheduleRecurringExpenseReminder({
    required String recurringExpenseId,
    required String categoryName,
    required double amount,
    required DateTime scheduledDate,
    String? description,
  }) {
    return _notificationService.scheduleRecurringExpenseReminder(
      recurringExpenseId: recurringExpenseId,
      categoryName: categoryName,
      amount: amount,
      scheduledDate: scheduledDate,
      description: description,
    );
  }

  @override
  Future<void> cancelRecurringExpenseReminder(String recurringExpenseId) {
    return _notificationService.cancelRecurringExpenseReminder(
      recurringExpenseId,
    );
  }

  @override
  Future<void> cancelAllScheduledNotifications() {
    return _notificationService.cancelAllScheduledNotifications();
  }
}

/// Mantém os lembretes sincronizados com as despesas recorrentes.
///
/// Uma recorrência terá um lembrete agendado somente quando:
///
/// - as notificações estiverem ativadas no Perfil;
/// - o sistema permitir notificações;
/// - a recorrência estiver ativa;
/// - a próxima data estiver no futuro.
///
/// Recorrências pausadas, vencidas ou excluídas terão o lembrete cancelado.
class RecurringNotificationScheduler {
  RecurringNotificationScheduler({
    RecurringNotificationService? notificationService,
    RecurringExpenseRepository? repository,
    DateTime Function()? nowProvider,
  }) : _notificationService =
           notificationService ?? _NotificationServiceAdapter(),
       _repository = repository ?? RecurringExpenseRepository(),
       _nowProvider = nowProvider ?? DateTime.now;

  static final RecurringNotificationScheduler instance =
      RecurringNotificationScheduler();

  static const String notificationsEnabledKey = 'notificationsEnabled';

  final RecurringNotificationService _notificationService;
  final RecurringExpenseRepository _repository;
  final DateTime Function() _nowProvider;

  /// Verifica a preferência salva no aplicativo.
  Future<bool> areNotificationsEnabledByUser() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return preferences.getBool(notificationsEnabledKey) ?? false;
  }

  /// Sincroniza o lembrete de apenas uma recorrência.
  ///
  /// Retorna `true` quando um lembrete foi agendado.
  /// Retorna `false` quando ele foi cancelado ou não precisava ser criado.
  Future<bool> synchronizeRecurringExpense(
    RecurringExpense recurringExpense,
  ) async {
    await _notificationService.initialize();

    final bool enabledByUser = await areNotificationsEnabledByUser();

    if (!enabledByUser) {
      await cancelRecurringExpense(recurringExpense.id);

      return false;
    }

    final bool permissionAllowed = await _notificationService
        .areNotificationsAllowed();

    if (!permissionAllowed) {
      await cancelRecurringExpense(recurringExpense.id);

      return false;
    }

    final DateTime now = _nowProvider();

    final bool shouldSchedule =
        recurringExpense.isActive && recurringExpense.nextDate.isAfter(now);

    if (!shouldSchedule) {
      await cancelRecurringExpense(recurringExpense.id);

      return false;
    }

    await _notificationService.scheduleRecurringExpenseReminder(
      recurringExpenseId: recurringExpense.id,
      categoryName: recurringExpense.categoryName,
      amount: recurringExpense.amount,
      scheduledDate: recurringExpense.nextDate,
      description: recurringExpense.description,
    );

    return true;
  }

  /// Sincroniza todas as recorrências atualmente salvas.
  ///
  /// Será utilizado:
  ///
  /// - quando as notificações forem ativadas;
  /// - quando o aplicativo iniciar;
  /// - após restauração de backup.
  Future<RecurringNotificationSyncResult>
  synchronizeAllRecurringExpenses() async {
    await _notificationService.initialize();

    final bool enabledByUser = await areNotificationsEnabledByUser();

    final bool permissionAllowed = enabledByUser
        ? await _notificationService.areNotificationsAllowed()
        : false;

    final List<RecurringExpense> recurringExpenses = await _repository
        .getAllRecurringExpenses();

    int scheduledCount = 0;
    int cancelledCount = 0;

    final DateTime now = _nowProvider();

    for (final RecurringExpense recurringExpense in recurringExpenses) {
      final bool shouldSchedule =
          enabledByUser &&
          permissionAllowed &&
          recurringExpense.isActive &&
          recurringExpense.nextDate.isAfter(now);

      if (shouldSchedule) {
        await _notificationService.scheduleRecurringExpenseReminder(
          recurringExpenseId: recurringExpense.id,
          categoryName: recurringExpense.categoryName,
          amount: recurringExpense.amount,
          scheduledDate: recurringExpense.nextDate,
          description: recurringExpense.description,
        );

        scheduledCount++;
      } else {
        await cancelRecurringExpense(recurringExpense.id);

        cancelledCount++;
      }
    }

    return RecurringNotificationSyncResult(
      scheduledCount: scheduledCount,
      cancelledCount: cancelledCount,
      notificationsEnabled: enabledByUser,
      permissionAllowed: permissionAllowed,
    );
  }

  /// Cancela o lembrete de uma recorrência.
  Future<void> cancelRecurringExpense(String recurringExpenseId) async {
    await _notificationService.initialize();

    await _notificationService.cancelRecurringExpenseReminder(
      recurringExpenseId,
    );
  }

  /// Cancela todos os lembretes futuros do aplicativo.
  Future<void> cancelAllScheduledNotifications() async {
    await _notificationService.initialize();

    await _notificationService.cancelAllScheduledNotifications();
  }
}
