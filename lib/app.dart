import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/presentation/lock_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/theme_notifier.dart';
import 'features/shell/presentation/main_shell.dart';

class FinanseApp extends StatelessWidget {
  const FinanseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (BuildContext context, ThemeState themeState, Widget? child) {
        return MaterialApp(
          title: 'Finanse',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('pt', 'BR')],
          theme: AppTheme.light(themeState.color),
          darkTheme: AppTheme.dark(themeState.color),
          themeMode: themeState.mode,
          builder: (BuildContext context, Widget? child) {
            final ThemeData theme = Theme.of(context);

            final bool isDark = theme.brightness == Brightness.dark;

            final Brightness iconBrightness = isDark
                ? Brightness.light
                : Brightness.dark;

            final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
              // O fundo do aplicativo passa por trás da barra.
              statusBarColor: Colors.transparent,

              // Mantém relógio, bateria e sinal legíveis.
              statusBarIconBrightness: iconBrightness,

              // Utilizado principalmente pelo iOS.
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,

              // Evita que o Android acrescente uma faixa automática.
              systemStatusBarContrastEnforced: false,

              // Mantém também a área inferior integrada ao aplicativo.
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: iconBrightness,
              systemNavigationBarContrastEnforced: false,
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const LockScreen(child: MainShell()),
        );
      },
    );
  }
}
