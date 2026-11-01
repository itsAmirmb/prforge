import 'package:flutter/material.dart';

/// Design tokens. Use these instead of raw numbers so spacing, corners and
/// motion stay consistent across screens (4 dp rhythm).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Space kept at the end of scrolling lists so the FAB never covers the
  /// last item.
  static const fabClearance = 88.0;

  /// Horizontal inset of cards in lists.
  static const cardInset = 12.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;

  /// [d], or no animation when the user turned animations off.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Widest content on large screens (tablets): the app column is centered.
const kMaxContentWidth = 720.0;

/// Semantic colors on top of Material's scheme. "Success" (a finished set)
/// is the scheme's tertiary role, which this theme sets to green.
extension AppColors on ColorScheme {
  Color get success => tertiary;
  Color get onSuccess => onTertiary;
  Color get successContainer => tertiaryContainer;
  Color get onSuccessContainer => onTertiaryContainer;
}

const _seed = Color(0xFFF97316);

ColorScheme _scheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return brightness == Brightness.light
      ? base.copyWith(
          tertiary: const Color(0xFF15803D),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFDCFCE7),
          onTertiaryContainer: const Color(0xFF14532D),
        )
      : base.copyWith(
          tertiary: const Color(0xFF4ADE80),
          onTertiary: const Color(0xFF052E16),
          tertiaryContainer: const Color(0xFF14532D),
          onTertiaryContainer: const Color(0xFFBBF7D0),
        );
}

TextTheme _textTheme(TextTheme t) => t.copyWith(
  headlineSmall: t.headlineSmall?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  ),
  titleLarge: t.titleLarge?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  ),
  titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
  labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
);

/// App theme for both brightness modes (same seed, same component styles).
ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = _textTheme(base.textTheme);

  const buttonSize = WidgetStatePropertyAll(Size(64, 48));
  final menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardInset,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline.withValues(alpha: 0.6)),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
    ),
    filledButtonTheme: const FilledButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize),
    ),
    outlinedButtonTheme: const OutlinedButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize),
    ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(minimumSize: buttonSize),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: menuShape,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: menuShape,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: AppSpacing.sm,
      iconColor: scheme.onSurfaceVariant,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
