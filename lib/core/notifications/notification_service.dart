import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Executado quando uma notificação é tocada enquanto o aplicativo
/// está encerrado ou funcionando em segundo plano.
///
/// Este método precisa permanecer no nível superior do arquivo.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
    'Notificação tocada em segundo plano: '
    '${notificationResponse.payload}',
  );
}

/// Resultado da solicitação das permissões de notificações.
class NotificationPermissionResult {
  const NotificationPermissionResult({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  /// Permissão para o aplicativo mostrar notificações.
  final bool notificationsAllowed;

  /// Permissão para realizar agendamentos em horário exato.
  final bool exactAlarmsAllowed;

  /// As duas permissões necessárias foram concedidas.
  bool get fullyGranted {
    return notificationsAllowed && exactAlarmsAllowed;
  }
}

/// Centraliza todas as operações relacionadas às notificações locais.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String recurringChannelId = 'finanse_recurring_expenses_v1';

  static const String recurringChannelName = 'Despesas recorrentes';

  static const String recurringChannelDescription =
      'Lembretes de contas, assinaturas e despesas recorrentes.';

  static const int _immediateTestNotificationId = 2000000001;

  static const int _scheduledTestNotificationId = 2000000002;

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      recurringChannelId,
      recurringChannelName,
      channelDescription: recurringChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.private,
      ticker: 'Lembrete financeiro',
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'finanse_recurring_expenses',
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'finanse_recurring_expenses',
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Payload da última notificação tocada.
  ///
  /// Posteriormente será usado para abrir diretamente a tela de
  /// despesas recorrentes.
  final ValueNotifier<String?> selectedPayload = ValueNotifier<String?>(null);

  bool _isInitialized = false;

  Future<void>? _initializationFuture;

  bool get isInitialized => _isInitialized;

  /// Inicializa o plugin, o fuso horário e o canal de notificações.
  ///
  /// Este método não solicita permissões automaticamente. A permissão
  /// será solicitada quando o usuário ativar as notificações no Perfil.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final Future<void>? existingInitialization = _initializationFuture;

    if (existingInitialization != null) {
      return existingInitialization;
    }

    final Future<void> initialization = _initializeInternal();

    _initializationFuture = initialization;

    try {
      await initialization;
      _isInitialized = true;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    await _configureLocalTimeZone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const IOSInitializationSettings iosSettings = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const DarwinInitializationSettings macOSSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          macOS: macOSSettings,
        );

    final bool? initialized = await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (initialized == false) {
      throw StateError('Não foi possível inicializar as notificações.');
    }

    await _createAndroidNotificationChannel();

    final NotificationAppLaunchDetails? launchDetails = await _plugin
        .getNotificationAppLaunchDetails();

    final NotificationResponse? response = launchDetails?.notificationResponse;

    if (launchDetails?.didNotificationLaunchApp == true &&
        response?.payload != null) {
      selectedPayload.value = response!.payload;
    }
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();

    try {
      final TimezoneInfo timeZoneInfo =
          await FlutterTimezone.getLocalTimezone();

      final tz.Location deviceLocation = tz.getLocation(
        timeZoneInfo.identifier,
      );

      tz.setLocalLocation(deviceLocation);
    } catch (error, stackTrace) {
      debugPrint(
        'Não foi possível identificar o fuso do aparelho. '
        'Usando America/Sao_Paulo.\n'
        '$error\n'
        '$stackTrace',
      );

      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }
  }

  Future<void> _createAndroidNotificationChannel() async {
    if (!Platform.isAndroid) {
      return;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _androidImplementation;

    if (androidImplementation == null) {
      return;
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      recurringChannelId,
      recurringChannelName,
      description: recurringChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidImplementation.createNotificationChannel(channel);
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidImplementation {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  /// Solicita permissão para mostrar notificações.
  ///
  /// No Android moderno, também pode solicitar autorização para alarmes
  /// exatos. Essa segunda permissão abre a tela de configurações do sistema.
  Future<NotificationPermissionResult> requestPermissions({
    bool requestExactAlarms = true,
  }) async {
    await _ensureInitialized();

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _androidImplementation;

      if (androidImplementation == null) {
        return const NotificationPermissionResult(
          notificationsAllowed: false,
          exactAlarmsAllowed: false,
        );
      }

      final bool notificationsAllowed =
          await androidImplementation.requestNotificationsPermission() ??
          await androidImplementation.areNotificationsEnabled() ??
          true;

      bool exactAlarmsAllowed =
          await androidImplementation.canScheduleExactNotifications() ?? true;

      if (requestExactAlarms && !exactAlarmsAllowed) {
        exactAlarmsAllowed =
            await androidImplementation.requestExactAlarmsPermission() ??
            await androidImplementation.canScheduleExactNotifications() ??
            false;
      }

      return NotificationPermissionResult(
        notificationsAllowed: notificationsAllowed,
        exactAlarmsAllowed: exactAlarmsAllowed,
      );
    }

    if (Platform.isIOS) {
      final bool notificationsAllowed =
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;

      return NotificationPermissionResult(
        notificationsAllowed: notificationsAllowed,
        exactAlarmsAllowed: true,
      );
    }

    if (Platform.isMacOS) {
      final bool notificationsAllowed =
          await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;

      return NotificationPermissionResult(
        notificationsAllowed: notificationsAllowed,
        exactAlarmsAllowed: true,
      );
    }

    return const NotificationPermissionResult(
      notificationsAllowed: true,
      exactAlarmsAllowed: true,
    );
  }

  /// Verifica se o Android permite que o aplicativo mostre notificações.
  Future<bool> areNotificationsAllowed() async {
    await _ensureInitialized();

    if (!Platform.isAndroid) {
      return true;
    }

    return await _androidImplementation?.areNotificationsEnabled() ?? false;
  }

  /// Verifica se o Android permite agendamentos em horários exatos.
  Future<bool> canScheduleExactNotifications() async {
    await _ensureInitialized();

    if (!Platform.isAndroid) {
      return true;
    }

    return await _androidImplementation?.canScheduleExactNotifications() ??
        false;
  }

  /// Mostra uma notificação imediatamente.
  ///
  /// Será usada para confirmar visualmente que a permissão foi concedida.
  Future<void> showTestNotification() async {
    await _ensureInitialized();

    await _plugin.show(
      id: _immediateTestNotificationId,
      title: 'Notificações ativadas',
      body: 'O Finanse poderá lembrar você das despesas recorrentes.',
      notificationDetails: _reminderDetails,
      payload: 'notification_test',
    );
  }

  /// Agenda uma notificação de teste.
  ///
  /// Retorna o horário em que ela deverá aparecer.
  Future<DateTime> scheduleTestNotification({
    Duration delay = const Duration(seconds: 10),
  }) async {
    await _ensureInitialized();

    final DateTime scheduledDate = DateTime.now().add(delay);

    await _plugin.cancel(id: _scheduledTestNotificationId);

    await _scheduleNotification(
      id: _scheduledTestNotificationId,
      title: 'Teste de lembrete',
      body: 'Esta notificação foi programada pelo Finanse.',
      scheduledDate: scheduledDate,
      payload: 'scheduled_notification_test',
    );

    return scheduledDate;
  }

  /// Agenda o lembrete de uma despesa recorrente.
  ///
  /// Cada recorrência possui um ID fixo de notificação. Ao editar a data,
  /// o lembrete anterior é substituído automaticamente.
  Future<void> scheduleRecurringExpenseReminder({
    required String recurringExpenseId,
    required String categoryName,
    required double amount,
    required DateTime scheduledDate,
    String? description,
  }) async {
    await _ensureInitialized();

    if (recurringExpenseId.trim().isEmpty) {
      throw ArgumentError.value(
        recurringExpenseId,
        'recurringExpenseId',
        'O ID da recorrência não pode ficar vazio.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'O valor precisa ser maior que zero.',
      );
    }

    final int notificationId = notificationIdForRecurringExpense(
      recurringExpenseId,
    );

    final String formattedAmount = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(amount);

    final String normalizedDescription = description?.trim() ?? '';

    final String body = normalizedDescription.isEmpty
        ? '$categoryName • $formattedAmount está previsto para agora.'
        : '$normalizedDescription • $formattedAmount em $categoryName.';

    await _plugin.cancel(id: notificationId);

    await _scheduleNotification(
      id: notificationId,
      title: 'Hora de registrar uma despesa',
      body: body,
      scheduledDate: scheduledDate,
      payload: 'recurring_expense:${recurringExpenseId.trim()}',
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    final tz.TZDateTime zonedDate = _toLocalTimeZone(scheduledDate);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (!zonedDate.isAfter(now)) {
      throw ArgumentError.value(
        scheduledDate,
        'scheduledDate',
        'O horário da notificação precisa estar no futuro.',
      );
    }

    final bool exactAlarmsAllowed = await canScheduleExactNotifications();

    final AndroidScheduleMode scheduleMode = exactAlarmsAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: zonedDate,
      notificationDetails: _reminderDetails,
      androidScheduleMode: scheduleMode,
      payload: payload,
    );
  }

  /// Cancela o lembrete pertencente a uma recorrência.
  Future<void> cancelRecurringExpenseReminder(String recurringExpenseId) async {
    await _ensureInitialized();

    final int notificationId = notificationIdForRecurringExpense(
      recurringExpenseId,
    );

    await _plugin.cancel(id: notificationId);
  }

  /// Retorna todas as notificações que ainda aguardam o horário programado.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await _ensureInitialized();

    return _plugin.pendingNotificationRequests();
  }

  /// Cancela somente notificações futuras.
  ///
  /// Notificações que já estão visíveis na barra do Android não são removidas.
  Future<void> cancelAllScheduledNotifications() async {
    await _ensureInitialized();

    await _plugin.cancelAllPendingNotifications();
  }

  /// Gera um número estável para a notificação de uma recorrência.
  ///
  /// O mesmo ID da recorrência sempre produzirá o mesmo ID de notificação.
  int notificationIdForRecurringExpense(String recurringExpenseId) {
    final String normalizedId = recurringExpenseId.trim();

    int hash = 0x811c9dc5;

    for (final int codeUnit in normalizedId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    return 100000 + (hash % 1900000000);
  }

  tz.TZDateTime _toLocalTimeZone(DateTime date) {
    return tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    selectedPayload.value = response.payload;

    debugPrint('Notificação tocada: ${response.payload}');
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    await initialize();
  }
}
