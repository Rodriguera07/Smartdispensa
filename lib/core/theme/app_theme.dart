import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema Material 3 completo do Smart Dispensa.
///
/// - Títulos: **Plus Jakarta Sans** (personalidade, peso visual).
/// - Dados e leitura: **Inter** (legibilidade máxima em números e listas).
/// - Áreas de toque mínimas de 56dp e textos com alto contraste para que
///   usuários de todas as idades usem o app sem dificuldade.
abstract final class AppTheme {
  /// Altura mínima de botões principais (acessibilidade).
  static const double minTouchTarget = 56;

  static const double radiusS = 12;
  static const double radiusM = 18;
  static const double radiusL = 26;

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final primary = isDark ? AppColors.mint : AppColors.mintDark;
    final onSurface = isDark ? AppColors.textOnDark : AppColors.textOnLight;
    final onSurfaceMuted =
        isDark ? AppColors.textOnDarkMuted : AppColors.textOnLightMuted;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? AppColors.petroleum : Colors.white,
      primaryContainer: primary.withValues(alpha: 0.18),
      onPrimaryContainer: onSurface,
      secondary: AppColors.cyan,
      onSecondary: AppColors.petroleum,
      secondaryContainer: AppColors.cyan.withValues(alpha: 0.18),
      onSecondaryContainer: onSurface,
      tertiary: AppColors.gold,
      onTertiary: AppColors.petroleum,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.petroleum : AppColors.lightBackground,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceMuted,
      surfaceContainerHighest:
          isDark ? const Color(0xFF16283D) : const Color(0xFFE3EAF0),
      surfaceContainerHigh:
          isDark ? const Color(0xFF132437) : const Color(0xFFEAF0F4),
      surfaceContainer:
          isDark ? const Color(0xFF102033) : const Color(0xFFF0F4F7),
      outline: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
      outlineVariant:
          isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
      shadow: Colors.black,
    );

    final textTheme = _textTheme(onSurface, onSurfaceMuted);

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusM),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      // O fundo real é o gradiente (GradientBackground); o Scaffold fica
      // transparente para deixá-lo aparecer.
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: roundedShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          foregroundColor: onSurface,
          side: BorderSide(color: colorScheme.outline, width: 1.2),
          textStyle: textTheme.titleMedium,
          shape: roundedShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.glassFillDark : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        labelStyle: textTheme.bodyLarge?.copyWith(color: onSurfaceMuted),
        hintStyle: textTheme.bodyLarge?.copyWith(color: onSurfaceMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: onSurfaceMuted, width: 2),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        side: BorderSide(color: colorScheme.outline),
        labelStyle: textTheme.labelLarge,
        backgroundColor:
            isDark ? AppColors.glassFillDark : Colors.white.withValues(alpha: 0.8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1B3047) : AppColors.petroleum,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: Colors.white),
        shape: roundedShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF0E2136) : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF10243A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: isDark ? const Color(0xF20D1E31) : const Color(0xF2FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      dividerTheme: DividerThemeData(color: colorScheme.outline, space: 1),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          selectedBackgroundColor: primary.withValues(alpha: 0.2),
          selectedForegroundColor: onSurface,
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color color, Color muted) {
    // Títulos — Plus Jakarta Sans
    TextStyle heading(double size, FontWeight weight) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: -0.3,
          height: 1.2,
        );

    // Leitura / dados — Inter
    TextStyle body(double size, FontWeight weight, {Color? c}) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: c ?? color,
          height: 1.4,
        );

    return TextTheme(
      displayLarge: heading(48, FontWeight.w800),
      displayMedium: heading(40, FontWeight.w800),
      displaySmall: heading(34, FontWeight.w800),
      headlineLarge: heading(30, FontWeight.w800),
      headlineMedium: heading(26, FontWeight.w700),
      headlineSmall: heading(22, FontWeight.w700),
      titleLarge: heading(20, FontWeight.w700),
      titleMedium: heading(17, FontWeight.w700),
      titleSmall: heading(15, FontWeight.w600),
      // Corpo com 16sp mínimo: confortável para idosos.
      bodyLarge: body(17, FontWeight.w400),
      bodyMedium: body(15, FontWeight.w400),
      bodySmall: body(13, FontWeight.w400, c: muted),
      labelLarge: body(16, FontWeight.w600),
      labelMedium: body(14, FontWeight.w600),
      labelSmall: body(12, FontWeight.w600, c: muted),
    );
  }
}

/// Atalhos de contexto para deixar as telas mais legíveis.
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
