import 'package:flutter/material.dart';

/// Paleta central de cores do Finanse.
///
/// Evite declarar códigos hexadecimais diretamente nas telas.
/// Sempre que possível, use uma cor desta classe ou o ColorScheme do tema.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Cor principal
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFF3DDC78);
  static const Color primaryDark = Color(0xFF24B95B);
  static const Color primarySoft = Color(0x263DDC78);

  // ---------------------------------------------------------------------------
  // Tema escuro
  // ---------------------------------------------------------------------------

  static const Color darkBackground = Color(0xFF071017);
  static const Color darkSurface = Color(0xFF101A21);
  static const Color darkSurfaceSecondary = Color(0xFF17232B);
  static const Color darkBorder = Color(0xFF24323A);

  static const Color darkTextPrimary = Color(0xFFF4F7F5);
  static const Color darkTextSecondary = Color(0xFFA7B2B8);
  static const Color darkTextMuted = Color(0xFF738087);

  static const Color darkDisabled = Color(0xFF4C585E);
  static const Color darkDivider = Color(0xFF24323A);
  static const Color darkNavigation = Color(0xFF101A21);

  // ---------------------------------------------------------------------------
  // Tema claro
  // ---------------------------------------------------------------------------

  static const Color lightBackground = Color(0xFFF5F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFEAF0EC);
  static const Color lightBorder = Color(0xFFDCE4DF);

  static const Color lightTextPrimary = Color(0xFF152019);
  static const Color lightTextSecondary = Color(0xFF58635D);
  static const Color lightTextMuted = Color(0xFF89938D);

  static const Color lightDisabled = Color(0xFFB8C1BC);
  static const Color lightDivider = Color(0xFFDCE4DF);
  static const Color lightNavigation = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Estados da interface
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF24B95B);
  static const Color warning = Color(0xFFF5A524);
  static const Color error = Color(0xFFFF6464);
  static const Color information = Color(0xFF55BCEB);

  static const Color successSoft = Color(0x2624B95B);
  static const Color warningSoft = Color(0x26F5A524);
  static const Color errorSoft = Color(0x26FF6464);
  static const Color informationSoft = Color(0x2655BCEB);

  // ---------------------------------------------------------------------------
  // Categorias
  // ---------------------------------------------------------------------------

  static const Color food = primary;
  static const Color transport = Color(0xFF55BCEB);
  static const Color housing = Color(0xFFFF913D);
  static const Color shopping = Color(0xFFFF7197);
  static const Color health = Color(0xFFFF6464);
  static const Color leisure = Color(0xFF9675FF);
  static const Color bills = Color(0xFFF5C451);
  static const Color other = Color(0xFF8A959D);

  // ---------------------------------------------------------------------------
  // Nomes antigos preservados para não quebrar as telas existentes
  // ---------------------------------------------------------------------------

  static const Color orange = Color(0xFFFF913D);
  static const Color purple = Color(0xFF9675FF);
  static const Color blue = Color(0xFF55BCEB);
  static const Color pink = Color(0xFFFF7197);
  static const Color yellow = Color(0xFFF5C451);
  static const Color red = Color(0xFFFF6464);

  // ---------------------------------------------------------------------------
  // Utilitários
  // ---------------------------------------------------------------------------

  /// Retorna a cor de superfície principal conforme o tema.
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  /// Retorna a superfície secundária conforme o tema.
  static Color surfaceSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurfaceSecondary
        : lightSurfaceSecondary;
  }

  /// Retorna a borda adequada ao tema atual.
  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  /// Retorna a cor principal dos textos.
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  /// Retorna a cor dos textos secundários.
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  /// Retorna a cor dos textos de menor destaque.
  static Color textMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextMuted
        : lightTextMuted;
  }

  /// Retorna a cor usada em componentes desabilitados.
  static Color disabled(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDisabled
        : lightDisabled;
  }
}