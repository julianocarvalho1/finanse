import 'package:flutter/material.dart';

import 'core/features/shell/presentation/main_shell.dart';
import 'core/features/theme/app_theme.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/main_shell.dart';

class FinanseApp extends StatelessWidget {
  const FinanseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finan\$e',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );
  }
}