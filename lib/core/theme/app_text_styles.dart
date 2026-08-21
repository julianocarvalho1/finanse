import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centraliza a hierarquia tipográfica do aplicativo.
///
/// Nas telas, prefira utilizar:
///
/// Theme.of(context).textTheme.headlineSmall
/// Theme.of(context).textTheme.titleLarge
/// Theme.of(context).textTheme.bodyMedium
///
/// Isso permite que os textos se adaptem automaticamente aos temas
/// claro e escuro.
abstract final class AppTextStyles {
  static const String? fontFamily = null;

  static TextTheme get lightTextTheme {
    return _buildTextTheme(
      primaryColor: AppColors.lightTextPrimary,
      secondaryColor: AppColors.lightTextSecondary,
      mutedColor: AppColors.lightTextMuted,
    );
  }

  static TextTheme get darkTextTheme {
    return _buildTextTheme(
      primaryColor: AppColors.darkTextPrimary,
      secondaryColor: AppColors.darkTextSecondary,
      mutedColor: AppColors.darkTextMuted,
    );
  }

  static TextTheme _buildTextTheme({
    required Color primaryColor,
    required Color secondaryColor,
    required Color mutedColor,
  }) {
    return TextTheme(
      /// Valor financeiro principal.
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: primaryColor,
      ),

      /// Título principal da página.
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primaryColor,
      ),

      /// Título de seção.
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primaryColor,
      ),

      /// Título de cartão ou item.
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),

      /// Título pequeno.
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),

      /// Texto de maior destaque.
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: primaryColor,
      ),

      /// Texto normal.
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),

      /// Texto secundário e descrições pequenas.
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),

      /// Texto de botões principais.
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: primaryColor,
      ),

      /// Rótulos, filtros e chips.
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),

      /// Legendas, datas e horários.
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
    );
  }

  /// Estilo específico para valores financeiros menores.
  static TextStyle financialValue(
    BuildContext context, {
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.2,
      fontWeight: fontWeight,
      letterSpacing: -0.3,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Estilo para valores positivos.
  static TextStyle positiveValue(BuildContext context, {double fontSize = 14}) {
    return financialValue(
      context,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryDark,
    );
  }

  /// Estilo para erros, gastos acima do limite e ações destrutivas.
  static TextStyle negativeValue(BuildContext context, {double fontSize = 14}) {
    return financialValue(
      context,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: AppColors.red,
    );
  }
}
