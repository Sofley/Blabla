import 'package:flutter/material.dart';

/// Semantic colors for financial values and stages.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.buyerAccent,
    required this.sellerAccent,
    required this.border,
  });

  final Color positive;
  final Color negative;
  final Color neutral;
  final Color buyerAccent;
  final Color sellerAccent;
  final Color border;

  Color signed(double v) => v > 0 ? positive : (v < 0 ? negative : neutral);

  static FinanceColors of(BuildContext context) =>
      Theme.of(context).extension<FinanceColors>()!;

  @override
  FinanceColors copyWith({
    Color? positive,
    Color? negative,
    Color? neutral,
    Color? buyerAccent,
    Color? sellerAccent,
    Color? border,
  }) => FinanceColors(
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    neutral: neutral ?? this.neutral,
    buyerAccent: buyerAccent ?? this.buyerAccent,
    sellerAccent: sellerAccent ?? this.sellerAccent,
    border: border ?? this.border,
  );

  @override
  FinanceColors lerp(FinanceColors? other, double t) {
    if (other == null) return this;
    return FinanceColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      buyerAccent: Color.lerp(buyerAccent, other.buyerAccent, t)!,
      sellerAccent: Color.lerp(sellerAccent, other.sellerAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// "Financial Minimalism": neutral surfaces, one restrained accent,
/// hairline borders instead of shadows, tabular figures for numbers.
class AppTheme {
  AppTheme._();

  static const _accent = Color(0xFF1F4E5F);

  static const tabularFigures = [FontFeature.tabularFigures()];

  static ThemeData light() => _build(
    Brightness.light,
    scheme:
        ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: _accent,
          surface: const Color(0xFFFFFFFF),
          surfaceContainerLowest: const Color(0xFFF6F7F9),
          onSurface: const Color(0xFF15191E),
          onSurfaceVariant: const Color(0xFF5B6470),
          outlineVariant: const Color(0xFFE3E6EA),
        ),
    background: const Color(0xFFF6F7F9),
    finance: const FinanceColors(
      positive: Color(0xFF1E7F4F),
      negative: Color(0xFFB3261E),
      neutral: Color(0xFF5B6470),
      buyerAccent: Color(0xFF1F4E5F),
      sellerAccent: Color(0xFF8A5A14),
      border: Color(0xFFE3E6EA),
    ),
  );

  static ThemeData dark() => _build(
    Brightness.dark,
    scheme:
        ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF7FC4D8),
          onPrimary: const Color(0xFF00222C),
          surface: const Color(0xFF151A20),
          surfaceContainerLowest: const Color(0xFF0E1216),
          onSurface: const Color(0xFFE7EAEE),
          onSurfaceVariant: const Color(0xFF9AA4AF),
          outlineVariant: const Color(0xFF262D35),
        ),
    background: const Color(0xFF0E1216),
    finance: const FinanceColors(
      positive: Color(0xFF5BC98D),
      negative: Color(0xFFFF8A80),
      neutral: Color(0xFF9AA4AF),
      buyerAccent: Color(0xFF7FC4D8),
      sellerAccent: Color(0xFFE0B66A),
      border: Color(0xFF262D35),
    ),
  );

  static ThemeData _build(
    Brightness brightness, {
    required ColorScheme scheme,
    required Color background,
    required FinanceColors finance,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      ),
    );
    final hairline = BorderSide(color: finance.border);
    final radius = BorderRadius.circular(14);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text,
      extensions: [finance],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
      ),
      dividerTheme: DividerThemeData(
        color: finance.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: hairline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: finance.border,
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
