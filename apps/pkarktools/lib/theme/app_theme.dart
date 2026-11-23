import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Tokens de color del Arca.
class ArcaTokens extends ThemeExtension<ArcaTokens> {
  const ArcaTokens({
    required this.base,
    required this.raised,
    required this.sunken,
    required this.hairline,
    required this.muted,
    required this.shiny,
    required this.glow,
  });

  final Color base;
  final Color raised;
  final Color sunken;
  final Color hairline;
  final Color muted;
  final Color shiny;
  final Color glow;

  static const dark = ArcaTokens(
    base: Color(0xFF151927),
    raised: Color(0xFF1D2236),
    sunken: Color(0xFF10131F),
    hairline: Color(0x1FFFFFFF),
    muted: Color(0xFF9AA1BD),
    shiny: Color(0xFFFFD86B),
    glow: Color(0x33F2C14E),
  );

  static const light = ArcaTokens(
    base: Color(0xFFF2F3F8),
    raised: Color(0xFFFFFFFF),
    sunken: Color(0xFFE6E8F0),
    hairline: Color(0x1A151927),
    muted: Color(0xFF5D6480),
    shiny: Color(0xFFB98500),
    glow: Color(0x229A6B00),
  );

  @override
  ArcaTokens copyWith() => this;

  @override
  ArcaTokens lerp(ArcaTokens? other, double t) {
    if (other == null) return this;
    return ArcaTokens(
      base: Color.lerp(base, other.base, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      shiny: Color.lerp(shiny, other.shiny, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

extension ArcaThemeX on BuildContext {
  ArcaTokens get tokens => Theme.of(this).extension<ArcaTokens>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

/// Paleta alineada con el logo: dorado (corona y triángulo) como primario,
/// cian de los cristales como secundario y plata en los neutros.
abstract final class AppTheme {
  static const display = 'Bricolage';
  static const body = 'Manrope';

  /// Respaldo para los glifos que Manrope y Bricolage no tienen (♂ ♀ ★ ⚠ ⌘…):
  /// subconjuntos de Noto Sans Symbols empaquetados (tool/gen_symbol_fonts.py),
  /// para no depender de las fuentes del sistema ni salir como cuadros.
  static const symbolFallback = ['NotoSansSymbols', 'NotoSansSymbols2'];

  static TextStyle _t(String family, double size, FontWeight w, {double? height, double? spacing}) => TextStyle(
        fontFamily: family,
        fontFamilyFallback: symbolFallback,
        fontSize: size,
        fontWeight: w,
        fontVariations: [FontVariation('wght', w.value.toDouble())],
        height: height,
        letterSpacing: spacing,
      );

  static TextTheme _textTheme(Color ink, Color muted) {
    final t = TextTheme(
      displayLarge: _t(display, 52, FontWeight.w800, height: 1.0, spacing: -1.5),
      displayMedium: _t(display, 40, FontWeight.w800, height: 1.05, spacing: -1.0),
      displaySmall: _t(display, 32, FontWeight.w700, height: 1.1, spacing: -0.6),
      headlineLarge: _t(display, 28, FontWeight.w700, height: 1.15, spacing: -0.4),
      headlineMedium: _t(display, 24, FontWeight.w700, height: 1.2, spacing: -0.3),
      headlineSmall: _t(display, 20, FontWeight.w700, height: 1.25, spacing: -0.2),
      titleLarge: _t(body, 18, FontWeight.w700, height: 1.3),
      titleMedium: _t(body, 15, FontWeight.w700, height: 1.35),
      titleSmall: _t(body, 13, FontWeight.w700, height: 1.35),
      bodyLarge: _t(body, 16, FontWeight.w500, height: 1.5),
      bodyMedium: _t(body, 14, FontWeight.w500, height: 1.45),
      bodySmall: _t(body, 12, FontWeight.w500, height: 1.4),
      labelLarge: _t(body, 14, FontWeight.w700, height: 1.2),
      labelMedium: _t(body, 12, FontWeight.w600, height: 1.2),
      labelSmall: _t(body, 11, FontWeight.w600, height: 1.2, spacing: 0.2),
    );
    return t.apply(bodyColor: ink, displayColor: ink);
  }

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        tokens: ArcaTokens.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFF2C14E),
          onPrimary: Color(0xFF2A1F00),
          primaryContainer: Color(0xFF3A3017),
          onPrimaryContainer: Color(0xFFFFE3A1),
          secondary: Color(0xFF6FD3E6),
          onSecondary: Color(0xFF00323B),
          secondaryContainer: Color(0xFF164552),
          onSecondaryContainer: Color(0xFFC9F4FB),
          error: Color(0xFFFF7A70),
          onError: Color(0xFF3B0904),
          surface: Color(0xFF151927),
          onSurface: Color(0xFFECEEF7),
          onSurfaceVariant: Color(0xFF9AA1BD),
          surfaceContainerLowest: Color(0xFF10131F),
          surfaceContainerLow: Color(0xFF191D2E),
          surfaceContainer: Color(0xFF1D2236),
          surfaceContainerHigh: Color(0xFF262C45),
          surfaceContainerHighest: Color(0xFF2E3552),
          outline: Color(0xFF4A5274),
          outlineVariant: Color(0xFF2E3552),
        ),
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        tokens: ArcaTokens.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF8A5F00),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFFFE3A1),
          onPrimaryContainer: Color(0xFF2A1F00),
          secondary: Color(0xFF0B6E80),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFC9F1F8),
          onSecondaryContainer: Color(0xFF002A33),
          error: Color(0xFFB3261E),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFF2F3F8),
          onSurface: Color(0xFF151927),
          onSurfaceVariant: Color(0xFF5D6480),
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFF8F9FC),
          surfaceContainer: Color(0xFFFFFFFF),
          surfaceContainerHigh: Color(0xFFE9EBF2),
          surfaceContainerHighest: Color(0xFFE0E3EC),
          outline: Color(0xFFA9AFC6),
          outlineVariant: Color(0xFFD5D9E6),
        ),
      );

  static ThemeData _build({required Brightness brightness, required ArcaTokens tokens, required ColorScheme scheme}) {
    final text = _textTheme(scheme.onSurface, tokens.muted);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.base,
      textTheme: text,
      fontFamily: body,
      fontFamilyFallback: symbolFallback,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineSmall,
        foregroundColor: scheme.onSurface,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.sunken,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: tokens.muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: scheme.primary),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: tokens.muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.sunken,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : tokens.muted),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: text.labelMedium,
        side: BorderSide(color: tokens.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.raised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.headlineSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: tokens.hairline, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.sunken,
        labelStyle: text.bodyMedium?.copyWith(color: tokens.muted),
        floatingLabelStyle: text.labelLarge?.copyWith(color: scheme.primary),
        helperStyle: text.bodySmall?.copyWith(color: tokens.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: tokens.hairline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: tokens.hairline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        inactiveTrackColor: tokens.sunken,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: text.labelLarge,
          selectedBackgroundColor: scheme.primary.withValues(alpha: 0.18),
          selectedForegroundColor: scheme.onSurface,
          side: BorderSide(color: tokens.hairline),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
