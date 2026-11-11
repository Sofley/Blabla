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
    required this.refund,
  });

  final Color positive;
  final Color negative;
  final Color neutral;
  final Color buyerAccent;
  final Color sellerAccent;
  final Color border;

  /// VAT refund (income paid back to the intermediary).
  final Color refund;

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
    Color? refund,
  }) => FinanceColors(
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    neutral: neutral ?? this.neutral,
    buyerAccent: buyerAccent ?? this.buyerAccent,
    sellerAccent: sellerAccent ?? this.sellerAccent,
    border: border ?? this.border,
    refund: refund ?? this.refund,
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
      refund: Color.lerp(refund, other.refund, t)!,
    );
  }
}

/// "Financial Minimalism": neutral surfaces, one restrained accent,
/// hairline borders instead of shadows, tabular figures for numbers.
class AppTheme {
  AppTheme._();

  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Light theme. [glass] makes surfaces translucent over a background image.
  static ThemeData light({
    AccentColor accent = AccentColor.blue,
    bool glass = false,
  }) {
    final primary = accent.light;
    final background = const Color(0xFFF4F6F9);
    final surface = Colors.white;
    return _build(
      Brightness.light,
      glass: glass,
      scheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: glass ? surface.withValues(alpha: .88) : surface,
        surfaceContainerLowest: background,
        onSurface: const Color(0xFF15191E),
        onSurfaceVariant: const Color(0xFF5B6470),
        outlineVariant: const Color(0xFFE3E6EA),
      ),
      background: background,
      finance: FinanceColors(
        positive: const Color(0xFF1E7F4F),
        negative: const Color(0xFFB3261E),
        neutral: const Color(0xFF5B6470),
        buyerAccent: primary,
        sellerAccent: accent == AccentColor.amber
            ? const Color(0xFF00796B)
            : const Color(0xFF8A5A14),
        border: const Color(0xFFE3E6EA),
        refund: const Color(0xFF6A4FB3),
      ),
    );
  }

  /// AMOLED dark theme: true black background, near-black surfaces.
  static ThemeData dark({
    AccentColor accent = AccentColor.blue,
    bool glass = false,
  }) {
    final primary = accent.dark;
    const background = Color(0xFF000000);
    const surface = Color(0xFF0E0F11);
    return _build(
      Brightness.dark,
      glass: glass,
      scheme:
          ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.dark,
          ).copyWith(
            primary: primary,
            onPrimary: const Color(0xFF051018),
            surface: glass ? surface.withValues(alpha: .82) : surface,
            surfaceContainerLowest: background,
            surfaceContainerHighest: const Color(0xFF1A1C20),
            onSurface: const Color(0xFFE9ECEF),
            onSurfaceVariant: const Color(0xFF9AA4AF),
            outlineVariant: const Color(0xFF22262B),
          ),
      background: background,
      finance: FinanceColors(
        positive: const Color(0xFF5BC98D),
        negative: const Color(0xFFFF8A80),
        neutral: const Color(0xFF9AA4AF),
        buyerAccent: primary,
        sellerAccent: accent == AccentColor.amber
            ? const Color(0xFF4DD0C4)
            : const Color(0xFFE0B66A),
        border: const Color(0xFF22262B),
        refund: const Color(0xFFB9A5F5),
      ),
    );
  }

  static ThemeData _build(
    Brightness brightness, {
    required bool glass,
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

    final page = glass ? Colors.transparent : background;
    return base.copyWith(
      scaffoldBackgroundColor: page,
      textTheme: text,
      extensions: [finance],
      appBarTheme: AppBarTheme(
        backgroundColor: page,
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
        fillColor: glass ? background.withValues(alpha: .6) : background,
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

/// Accent colors offered in Settings (Samsung Galaxy style palette).
enum AccentColor {
  teal(Color(0xFF00796B), Color(0xFF4DD0C4)),
  amber(Color(0xFFB26A00), Color(0xFFFFC24A)),
  blue(Color(0xFF1E4FA8), Color(0xFF7FB2FF)),
  purple(Color(0xFF6B3FB3), Color(0xFFC3A6FF));

  const AccentColor(this.light, this.dark);

  final Color light;
  final Color dark;

  static AccentColor fromName(String? n) =>
      AccentColor.values.firstWhere((a) => a.name == n, orElse: () => blue);
}
