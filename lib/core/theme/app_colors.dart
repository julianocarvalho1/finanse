import 'package:flutter/material.dart';

/// Paleta central de cores do Finanse.
///
/// Evite declarar códigos hexadecimais diretamente nas telas.
/// Sempre que possível, use uma cor desta classe ou o ColorScheme do tema.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Cor principal padrão
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFF3DDC78);
  static const Color primaryDark = Color(0xFF24B95B);
  static const Color primarySoft = Color(0x263DDC78);

  // ---------------------------------------------------------------------------
  // Tema escuro
  // ---------------------------------------------------------------------------

  /// Fundo principal: escuro, mas sem ficar totalmente preto.
  static const Color darkBackground = Color(0xFF0A171F);

  /// Cartões e superfícies principais.
  static const Color darkSurface = Color(0xFF162630);

  /// Campos, opções, barras internas e superfícies secundárias.
  static const Color darkSurfaceSecondary = Color(0xFF102029);

  /// Bordas mais perceptíveis, sem ficarem chamativas.
  static const Color darkBorder = Color(0xFF2B3D47);

  static const Color darkTextPrimary = Color(0xFFF3F6F8);
  static const Color darkTextSecondary = Color(0xFFB2BDC4);
  static const Color darkTextMuted = Color(0xFF7E8D96);
  static const Color darkDisabled = Color(0xFF52616A);

  static const Color darkDivider = Color(0xFF2B3D47);

  /// Barra inferior levemente diferente do fundo principal.
  static const Color darkNavigation = Color(0xFF0E1E27);

  // ---------------------------------------------------------------------------
  // Tema claro
  // ---------------------------------------------------------------------------

  /// Fundo principal levemente acinzentado para destacar os cartões brancos.
  static const Color lightBackground = Color(0xFFF1F4F2);

  /// Cartões e superfícies principais.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Campos de busca, filtros e superfícies secundárias.
  static const Color lightSurfaceSecondary = Color(0xFFE7ECE9);

  /// Bordas mais visíveis para separar os elementos.
  static const Color lightBorder = Color(0xFFCDD6D1);

  static const Color lightTextPrimary = Color(0xFF152019);
  static const Color lightTextSecondary = Color(0xFF5F6C65);
  static const Color lightTextMuted = Color(0xFF66716B);
  static const Color lightDisabled = Color(0xFFAEB8B3);

  static const Color lightDivider = Color(0xFFD4DCD7);

  /// Barra inferior quase branca, mas separada do fundo da tela.
  static const Color lightNavigation = Color(0xFFFCFDFC);

  // ---------------------------------------------------------------------------
  // Estados da interface
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF24B95B);
  static const Color warning = Color(0xFFF5A524);
  static const Color error = Color(0xFFC62828);
  static const Color information = Color(0xFF55BCEB);

  static const Color successSoft = Color(0x2624B95B);
  static const Color warningSoft = Color(0x26F5A524);
  static const Color errorSoft = Color(0x26C62828);
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
  static const Color red = error;

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
