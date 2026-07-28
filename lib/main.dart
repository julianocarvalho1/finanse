import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'features/recurring_expenses/data/recurring_notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permite que a interface continue por trás das barras do sistema.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    // Prepara o plugin, o canal Android e o fuso horário do aparelho.
    await NotificationService.instance.initialize();

    // Confere todas as recorrências salvas e mantém os lembretes
    // sincronizados sempre que o aplicativo for iniciado.
    await RecurringNotificationScheduler.instance
        .synchronizeAllRecurringExpenses();
  } catch (error, stackTrace) {
    debugPrint(
      'Não foi possível sincronizar as notificações.\n'
      'O aplicativo continuará funcionando normalmente.\n'
      '$error\n'
      '$stackTrace',
    );
  }

  runApp(const FinanseApp());
}
