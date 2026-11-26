import 'package:material_ui/material_ui.dart';

/// Cohesive Terracotta, Warm Gold & Obsidian palette for Trono.
/// Keeps Tactile Chunky 3D depth while eliminating loud rainbow clutter.
class TronoColors {
  // Primary Terracotta (Hero CTA, Heatmap scale, Peak hour, Active nav)
  static const terracotta = Color(0xFFE05A2B);
  static const terracottaLip = Color(0xFFB54118);

  // Royal Warm Gold (Ranks, Unlocked badges, XP progress)
  static const gold = Color(0xFFF5B82E);
  static const goldLip = Color(0xFFC79014);

  // Obsidian Charcoal (Rank hero banner, Secondary tactile controls, Peak chart)
  static const obsidian = Color(0xFF1E222B);
  static const obsidianLip = Color(0xFF11141B);

  // Calm Forest Sage (Confirmations & Save CTA — never neon)
  static const sage = Color(0xFF2F855A);
  static const sageLip = Color(0xFF226443);

  // Destructive error
  static const coral = Color(0xFFD64545);

  // Light mode surfaces (Warm editorial cream)
  static const lightBg = Color(0xFFF7F4EE);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE4DDD0);
  static const lightLip = Color(0xFFD4CBB9);
  static const lightInk = Color(0xFF1E222B);
  static const lightMuted = Color(0xFF787166);

  // Dark mode surfaces (Deep warm obsidian)
  static const darkBg = Color(0xFF13161C);
  static const darkSurface = Color(0xFF1D212B);
  static const darkBorder = Color(0xFF303646);
  static const darkLip = Color(0xFF0C0E13);
  static const darkInk = Color(0xFFF5F2EB);
  static const darkMuted = Color(0xFF989DA8);

  static Color bg(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkBg : lightBg;
  static Color surface(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkSurface : lightSurface;
  static Color border(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkBorder : lightBorder;
  static Color lip(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkLip : lightLip;
  static Color ink(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkInk : lightInk;
  static Color muted(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkMuted : lightMuted;
}

class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: TronoColors.terracotta,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFBE4DC),
      onPrimaryContainer: Color(0xFF6E250B),
      secondary: TronoColors.gold,
      onSecondary: TronoColors.obsidian,
      secondaryContainer: Color(0xFFFEF3D2),
      onSecondaryContainer: Color(0xFF694B05),
      tertiary: TronoColors.obsidian,
      onTertiary: Colors.white,
      error: TronoColors.coral,
      onError: Colors.white,
      surface: TronoColors.lightSurface,
      onSurface: TronoColors.lightInk,
      onSurfaceVariant: TronoColors.lightMuted,
      outline: TronoColors.lightBorder,
      outlineVariant: TronoColors.lightBorder,
      surfaceContainerHighest: Color(0xFFEDE7DC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TronoColors.lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: TronoColors.lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: TronoColors.lightInk,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: TronoColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: TronoColors.lightBorder, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: TronoColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFFBE4DC),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: TronoColors.terracotta, size: 26);
          }
          return const IconThemeData(color: TronoColors.lightMuted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? TronoColors.terracotta : TronoColors.lightMuted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: TronoColors.lightBorder, width: 1.5),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: TronoColors.terracotta,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: TronoColors.lightBorder, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TronoColors.obsidian,
        showCloseIcon: true,
        closeIconColor: Colors.white70,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: TronoColors.terracotta,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF422217),
      onPrimaryContainer: Color(0xFFFFBFA9),
      secondary: TronoColors.gold,
      onSecondary: TronoColors.obsidian,
      secondaryContainer: Color(0xFF3A3014),
      onSecondaryContainer: Color(0xFFFDE08D),
      tertiary: Color(0xFFE2DFD7),
      onTertiary: TronoColors.obsidian,
      error: TronoColors.coral,
      onError: Colors.white,
      surface: TronoColors.darkSurface,
      onSurface: TronoColors.darkInk,
      onSurfaceVariant: TronoColors.darkMuted,
      outline: TronoColors.darkBorder,
      outlineVariant: TronoColors.darkBorder,
      surfaceContainerHighest: Color(0xFF272C38),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TronoColors.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: TronoColors.darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: TronoColors.darkInk,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: TronoColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: TronoColors.darkBorder, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: TronoColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF422217),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: TronoColors.terracotta, size: 26);
          }
          return const IconThemeData(color: TronoColors.darkMuted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? TronoColors.terracotta : TronoColors.darkMuted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: TronoColors.darkBorder, width: 1.5),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: TronoColors.terracotta,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: TronoColors.darkBorder, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF282D3A),
        showCloseIcon: true,
        closeIconColor: Colors.white70,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
