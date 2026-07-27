import 'package:flutter/material.dart';

/// Centraliza os espaçamentos, tamanhos e raios usados no aplicativo.
///
/// Evite colocar valores como 8, 16, 20 ou 24 diretamente nas telas.
/// Use as constantes desta classe para manter o visual padronizado.
class AppSpacing {
  AppSpacing._();

  // Espaçamentos básicos
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  // Espaçamentos de páginas
  static const double pageHorizontal = 20;
  static const double pageTop = 16;
  static const double pageBottom = 24;

  // Espaçamentos entre elementos
  static const double itemGap = 12;
  static const double sectionGap = 24;

  // Cartões e componentes
  static const double cardPadding = 16;
  static const double cardRadius = 20;
  static const double modalRadius = 24;
  static const double inputRadius = 14;
  static const double buttonRadius = 14;

  // Tamanhos mínimos para áreas tocáveis
  static const double minimumTouchSize = 48;
  static const double iconButtonSize = 48;

  // Navegação inferior e botão flutuante
  static const double bottomNavigationHeight = 72;
  static const double floatingActionButtonSize = 58;

  // Espaço extra para listas não ficarem escondidas
  static const double bottomContentClearance = 112;

  // Insets reutilizáveis
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
  );

  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);

  static const EdgeInsets sectionInsets = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: md,
  );

  /// Calcula o espaço inferior considerando a área segura do aparelho.
  ///
  /// Deve ser usado no final de listas e páginas roláveis para evitar que
  /// o conteúdo fique atrás da navegação inferior.
  static double safeBottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + bottomContentClearance;
  }
}