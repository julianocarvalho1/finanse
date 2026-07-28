import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Faz o aplicativo ocupar toda a tela, inclusive atrás das
  // barras superiores e inferiores do Android.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    await NotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint(
      'Não foi possível inicializar as notificações.\n'
      'O aplicativo continuará funcionando normalmente.\n'
      '$error\n'
      '$stackTrace',
    );
  }

  runApp(const FinanseApp());
}
