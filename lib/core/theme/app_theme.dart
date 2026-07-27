import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Configuração global dos temas claro e escuro do Finanse.
///
/// Os estilos gerais de botões, cartões, campos, modais e mensagens
/// devem ser configurados aqui para evitar repetição nas telas.
abstract final class AppTheme {
  /// Tema claro.
  static ThemeData light(Color seedColor) {
    return _buildTheme(
      brightness: Brightness.light,
      seedColor: seedColor,
      backgroundColor: AppColors.lightBackground,
      surfaceColor: AppColors.lightSurface,
      surfaceSecondaryColor: AppColors.lightSurfaceSecondary,
      borderColor: AppColors.lightBorder,
      dividerColor: AppColors.lightDivider,
      textPrimaryColor: AppColors.lightTextPrimary,
      textSecondaryColor: AppColors.lightTextSecondary,
      textMutedColor: AppColors.lightTextMuted,
      disabledColor: AppColors.lightDisabled,
      navigationColor: AppColors.lightNavigation,
      textTheme: AppTextStyles.lightTextTheme,
    );
  }

  /// Tema escuro.
  static ThemeData dark(Color seedColor) {
    return _buildTheme(
      brightness: Brightness.dark,
      seedColor: seedColor,
      backgroundColor: AppColors.darkBackground,
      surfaceColor: AppColors.darkSurface,
      surfaceSecondaryColor: AppColors.darkSurfaceSecondary,
      borderColor: AppColors.darkBorder,
      dividerColor: AppColors.darkDivider,
      textPrimaryColor: AppColors.darkTextPrimary,
      textSecondaryColor: AppColors.darkTextSecondary,
      textMutedColor: AppColors.darkTextMuted,
      disabledColor: AppColors.darkDisabled,
      navigationColor: AppColors.darkNavigation,
      textTheme: AppTextStyles.darkTextTheme,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seedColor,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color surfaceSecondaryColor,
    required Color borderColor,
    required Color dividerColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color textMutedColor,
    required Color disabledColor,
    required Color navigationColor,
    required TextTheme textTheme,
  }) {
    final Color foregroundOnPrimary = _foregroundFor(seedColor);

    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ).copyWith(
          primary: seedColor,
          onPrimary: foregroundOnPrimary,
          secondary: seedColor,
          onSecondary: foregroundOnPrimary,
          surface: surfaceColor,
          onSurface: textPrimaryColor,
          error: AppColors.error,
          onError: Colors.white,
          outline: borderColor,
          outlineVariant: dividerColor,
          surfaceContainerHighest: surfaceSecondaryColor,
        );

    final OutlineInputBorder defaultInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      borderSide: BorderSide(color: borderColor),
    );

    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      borderSide: BorderSide(color: seedColor, width: 1.6),
    );

    final OutlineInputBorder errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: surfaceColor,
      dividerColor: dividerColor,
      disabledColor: disabledColor,
      textTheme: textTheme,

      // -----------------------------------------------------------------------
      // Ícones
      // -----------------------------------------------------------------------
      iconTheme: IconThemeData(color: textSecondaryColor, size: 22),

      primaryIconTheme: IconThemeData(color: foregroundOnPrimary, size: 22),

      // -----------------------------------------------------------------------
      // Barra superior
      // -----------------------------------------------------------------------
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: textPrimaryColor),
        actionsIconTheme: IconThemeData(color: textPrimaryColor),
      ),

      // -----------------------------------------------------------------------
      // Cartões
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: borderColor),
        ),
      ),

      // -----------------------------------------------------------------------
      // Campos de texto
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaceSecondaryColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondaryColor),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: seedColor,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMutedColor),
        helperStyle: textTheme.bodySmall?.copyWith(color: textMutedColor),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
        prefixIconColor: textMutedColor,
        suffixIconColor: textMutedColor,
        border: defaultInputBorder,
        enabledBorder: defaultInputBorder,
        disabledBorder: defaultInputBorder.copyWith(
          borderSide: BorderSide(color: disabledColor.withOpacity(0.45)),
        ),
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),

      // -----------------------------------------------------------------------
      // Botão elevado
      // -----------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minimumTouchSize),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          backgroundColor: seedColor,
          foregroundColor: foregroundOnPrimary,
          disabledBackgroundColor: disabledColor.withOpacity(0.35),
          disabledForegroundColor: textMutedColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Botão preenchido
      // -----------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minimumTouchSize),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          backgroundColor: seedColor,
          foregroundColor: foregroundOnPrimary,
          disabledBackgroundColor: disabledColor.withOpacity(0.35),
          disabledForegroundColor: textMutedColor,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Botão com contorno
      // -----------------------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minimumTouchSize),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          foregroundColor: seedColor,
          disabledForegroundColor: textMutedColor,
          side: BorderSide(color: borderColor),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Botão de texto
      // -----------------------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTouchSize,
            AppSpacing.minimumTouchSize,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          foregroundColor: seedColor,
          disabledForegroundColor: textMutedColor,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Botões de ícone
      // -----------------------------------------------------------------------
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.iconButtonSize),
          foregroundColor: textSecondaryColor,
          disabledForegroundColor: disabledColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Botão flutuante
      // -----------------------------------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: foregroundOnPrimary,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 5,
      ),

      // -----------------------------------------------------------------------
      // Barra de navegação inferior antiga
      // -----------------------------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navigationColor,
        selectedItemColor: seedColor,
        unselectedItemColor: textMutedColor,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: seedColor,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: textMutedColor,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // -----------------------------------------------------------------------
      // Barra de navegação Material 3
      // -----------------------------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.bottomNavigationHeight,
        backgroundColor: navigationColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: seedColor.withOpacity(0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? seedColor : textMutedColor,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);

          return textTheme.labelSmall!.copyWith(
            color: selected ? seedColor : textMutedColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),

      // -----------------------------------------------------------------------
      // Listas
      // -----------------------------------------------------------------------
      listTileTheme: ListTileThemeData(
        iconColor: textSecondaryColor,
        textColor: textPrimaryColor,
        selectedColor: seedColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        minTileHeight: AppSpacing.minimumTouchSize,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
      ),

      // -----------------------------------------------------------------------
      // Divisores
      // -----------------------------------------------------------------------
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // -----------------------------------------------------------------------
      // Chips e filtros
      // -----------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSecondaryColor,
        selectedColor: seedColor.withOpacity(0.16),
        disabledColor: disabledColor.withOpacity(0.20),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        labelStyle: textTheme.labelMedium!.copyWith(color: textSecondaryColor),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(
          color: seedColor,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      // -----------------------------------------------------------------------
      // Caixas de seleção
      // -----------------------------------------------------------------------
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStatePropertyAll<Color>(foregroundOnPrimary),
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return disabledColor.withOpacity(0.35);
          }

          if (states.contains(WidgetState.selected)) {
            return seedColor;
          }

          return Colors.transparent;
        }),
        side: BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      // -----------------------------------------------------------------------
      // Interruptores
      // -----------------------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return disabledColor;
          }

          if (states.contains(WidgetState.selected)) {
            return foregroundOnPrimary;
          }

          return textMutedColor;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return disabledColor.withOpacity(0.25);
          }

          if (states.contains(WidgetState.selected)) {
            return seedColor;
          }

          return surfaceSecondaryColor;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return seedColor;
          }

          return borderColor;
        }),
      ),

      // -----------------------------------------------------------------------
      // Indicadores de carregamento e progresso
      // -----------------------------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: seedColor,
        linearTrackColor: surfaceSecondaryColor,
        circularTrackColor: surfaceSecondaryColor,
      ),

      // -----------------------------------------------------------------------
      // Modais inferiores
      // -----------------------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: textMutedColor.withOpacity(0.55),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.modalRadius),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // -----------------------------------------------------------------------
      // Caixas de diálogo
      // -----------------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        iconColor: textPrimaryColor,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),

      // -----------------------------------------------------------------------
      // Mensagens de sucesso e erro
      // -----------------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? AppColors.darkSurfaceSecondary
            : AppColors.lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: seedColor,
        closeIconColor: Colors.white,
        elevation: 5,
        insetPadding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
      ),

      // -----------------------------------------------------------------------
      // Menus
      // -----------------------------------------------------------------------
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          side: BorderSide(color: borderColor),
        ),
      ),

      // Mantém áreas de toque confortáveis para acessibilidade.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  /// Escolhe automaticamente uma cor legível sobre a cor principal.
  static Color _foregroundFor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.48
        ? const Color(0xFF101512)
        : Colors.white;
  }
}
