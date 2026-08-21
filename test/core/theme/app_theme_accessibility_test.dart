import 'package:finanse/core/theme/app_colors.dart';
import 'package:finanse/core/theme/app_spacing.dart';
import 'package:finanse/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<Color> selectableColors = <Color>[
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];

  test('cores personalizáveis mantêm contraste mínimo nos dois temas', () {
    for (final Color seed in selectableColors) {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(seed),
        AppTheme.dark(seed),
      ]) {
        final Color comparisonBackground = theme.brightness == Brightness.light
            ? theme.scaffoldBackgroundColor
            : theme.colorScheme.surface;
        expect(
          _contrast(theme.colorScheme.primary, comparisonBackground),
          greaterThanOrEqualTo(4.5),
          reason: 'cor principal ${seed.toARGB32().toRadixString(16)}',
        );
        expect(
          _contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: 'texto sobre a cor ${seed.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('textos-base e mensagens de erro atendem contraste normal', () {
    expect(
      _contrast(AppColors.lightTextPrimary, AppColors.lightBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.lightTextSecondary, AppColors.lightBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.lightTextMuted, AppColors.lightBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.darkTextMuted, AppColors.darkBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(Colors.white, AppColors.error), greaterThanOrEqualTo(4.5));
  });

  test('componentes interativos preservam área de toque de 48 pixels', () {
    final ThemeData theme = AppTheme.light(selectableColors.first);
    final Size? minimumButtonSize = theme.filledButtonTheme.style?.minimumSize
        ?.resolve(<WidgetState>{});

    expect(AppSpacing.minimumTouchSize, greaterThanOrEqualTo(48));
    expect(minimumButtonSize?.height, greaterThanOrEqualTo(48));
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
  });
}

double _contrast(Color first, Color second) {
  final double firstLuminance = first.computeLuminance();
  final double secondLuminance = second.computeLuminance();
  final double lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final double darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
