import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Representa o visual de uma categoria financeira.
class CategoryStyle {
  const CategoryStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  /// Cor suave para fundos de ícones, cartões e seleções.
  Color backgroundColor({double opacity = 0.14}) {
    return color.withValues(alpha: opacity);
  }
}

/// Centraliza os ícones e as cores das categorias do aplicativo.
///
/// As categorias padrão possuem estilos fixos.
/// Categorias personalizadas recebem automaticamente uma cor e um ícone
/// consistentes com base no nome.
abstract final class CategoryStyles {
  static const CategoryStyle food = CategoryStyle(
    icon: Icons.restaurant_rounded,
    color: AppColors.food,
  );

  static const CategoryStyle transport = CategoryStyle(
    icon: Icons.directions_car_filled_rounded,
    color: AppColors.transport,
  );

  static const CategoryStyle housing = CategoryStyle(
    icon: Icons.home_rounded,
    color: AppColors.housing,
  );

  static const CategoryStyle shopping = CategoryStyle(
    icon: Icons.shopping_bag_rounded,
    color: AppColors.shopping,
  );

  static const CategoryStyle health = CategoryStyle(
    icon: Icons.favorite_rounded,
    color: AppColors.health,
  );

  static const CategoryStyle leisure = CategoryStyle(
    icon: Icons.sports_esports_rounded,
    color: AppColors.leisure,
  );

  static const CategoryStyle bills = CategoryStyle(
    icon: Icons.receipt_long_rounded,
    color: AppColors.bills,
  );

  static const CategoryStyle other = CategoryStyle(
    icon: Icons.more_horiz_rounded,
    color: AppColors.other,
  );

  static const List<Color> _customColors = <Color>[
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFFAB47BC),
    Color(0xFFEC407A),
    Color(0xFFEF6C00),
    Color(0xFF7CB342),
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFFF4511E),
    Color(0xFF43A047),
  ];

  static const List<IconData> _customIcons = <IconData>[
    Icons.label_rounded,
    Icons.bookmark_rounded,
    Icons.folder_rounded,
    Icons.star_rounded,
    Icons.category_rounded,
    Icons.widgets_rounded,
    Icons.hexagon_rounded,
    Icons.circle_rounded,
  ];

  /// Retorna o estilo correspondente ao nome da categoria.
  ///
  /// A comparação ignora letras maiúsculas, espaços e acentos.
  static CategoryStyle fromName(String? categoryName) {
    final String normalizedName = _normalize(categoryName);

    switch (normalizedName) {
      case 'alimentacao':
      case 'alimentos':
      case 'comida':
        return food;

      case 'transporte':
        return transport;

      case 'moradia':
      case 'casa':
        return housing;

      case 'compras':
        return shopping;

      case 'saude':
        return health;

      case 'lazer':
        return leisure;

      case 'contas':
      case 'conta':
        return bills;

      case '':
      case 'outros':
      case 'outro':
        return other;

      default:
        return _customStyleFor(normalizedName);
    }
  }

  /// Retorna apenas o ícone da categoria.
  static IconData iconFor(String? categoryName) {
    return fromName(categoryName).icon;
  }

  /// Retorna apenas a cor da categoria.
  static Color colorFor(String? categoryName) {
    return fromName(categoryName).color;
  }

  static CategoryStyle _customStyleFor(String normalizedName) {
    final int hash = _stableHash(normalizedName);

    final Color color = _customColors[hash % _customColors.length];

    final IconData icon = _customIcons[hash % _customIcons.length];

    return CategoryStyle(icon: icon, color: color);
  }

  /// Gera um número estável a partir do nome.
  ///
  /// Assim, a mesma categoria mantém o mesmo visual após fechar e reabrir
  /// o aplicativo.
  static int _stableHash(String value) {
    int hash = 0;

    for (final int codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }

    return hash;
  }

  static String _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}
