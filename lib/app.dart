import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Biblioteca para controlar a bateria/hora do celular
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/presentation/main_shell.dart';
import 'core/presentation/lock_screen.dart';
import 'core/utils/theme_notifier.dart';

class FinanseApp extends StatelessWidget {
  const FinanseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (context, themeState, child) {

        // Descobre se o celular está no modo escuro atualmente
        final brightness = MediaQuery.platformBrightnessOf(context);
        final isDark = themeState.mode == ThemeMode.dark ||
            (themeState.mode == ThemeMode.system && brightness == Brightness.dark);

        // --- A MÁGICA DA BARRA DO CELULAR (TWITTER/X EFFECT) ---
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent, // Fundo transparente em cima
            systemNavigationBarColor: Colors.transparent, // Fundo transparente embaixo
            // Se o app estiver escuro, letras brancas. Se estiver claro, letras pretas!
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: MaterialApp(
            title: 'Finanse',
            debugShowCheckedModeBanner: false,

            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('pt', 'BR'),
            ],

            theme: AppTheme.light(themeState.color),
            darkTheme: AppTheme.dark(themeState.color),
            themeMode: themeState.mode,

            home: const LockScreen(
              child: MainShell(),
            ),
          ),
        );
      },
    );
  }
}