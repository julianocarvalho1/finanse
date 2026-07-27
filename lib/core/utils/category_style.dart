import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Representa o visual de uma categoria financeira.
class CategoryStyle {
  const CategoryStyle({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  /// Cor suave para fundos de ícones, cartões ou seleções.
  Color backgroundColor({double opacity = 0.14}) {
    return color.withOpacity(opacity);
  }
}

/// Centraliza os ícones e as cores de todas as categorias.
///
/// Use:
///
/// final style = CategoryStyles.fromName(expense.category);
///
/// Icon(style.icon, color: style.color);
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

  /// Retorna o estilo correspondente ao nome da categoria.
  ///
  /// A comparação ignora letras maiúsculas, espaços e acentos.
  /// Categorias personalizadas usam o estilo de "Outros".
  static CategoryStyle fromName(String? categoryName) {
    final normalizedName = _normalize(categoryName);

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

      case 'outros':
      case 'outro':
      default:
        return other;
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