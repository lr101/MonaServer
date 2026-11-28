import "package:buff_lisa/util/theme/data/app_color_scheme.dart";
import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,

      // PRIMARY: Warm Stick-It orange/amber brand accent
      primary: Color(0xFFFFB77C),
      onPrimary: Color(0xFF422100),
      primaryContainer: Color(0xFFE88F1D),
      onPrimaryContainer: Color(0xFF1F0E00),

      // SECONDARY: Cool slate for balanced technical contrast
      secondary: Color(0xFF37474F),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE4EBF0),
      onSecondaryContainer: Color(0xFF14222A),

      // TERTIARY: Muted teal for earned/completed accents
      tertiary: Color(0xFF006978),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFC4EEF4),
      onTertiaryContainer: Color(0xFF001F24),

      // SURFACES: Cool neutral canvas with crisp pure-white elevated surfaces
      surface: Color(0xFFF3F5F8),
      onSurface: Color(0xFF171C22),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAFBFD),
      surfaceContainer: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFEEF2F6),
      surfaceContainerHighest: Color(0xFFE2E7EE),
      onSurfaceVariant: Color(0xFF525B66),

      outline: Color(0xFF838B95),
      outlineVariant: Color(0xFFDCE2E9),

      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),

      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF282E35),
      inversePrimary: Color(0xFFFFB77C),
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,

      // PRIMARY: Warm lightened orange for dark mode visibility
      primary: Color(0xFFFFB77C),
      onPrimary: Color(0xFF422100),
      primaryContainer: Color(0xFFE88F1D),
      onPrimaryContainer: Color(0xFF1A0B00),

      // SECONDARY: Blue-grey
      secondary: Color(0xFFB0BEC5),
      onSecondary: Color(0xFF263238),
      secondaryContainer: Color(0xFF2E3A42),
      onSecondaryContainer: Color(0xFFECEFF1),

      // TERTIARY: Cyan accent
      tertiary: Color(0xFF4DD0E1),
      onTertiary: Color(0xFF00363D),
      tertiaryContainer: Color(0xFF004F58),
      onTertiaryContainer: Color(0xFF97F0FF),

      // SURFACES: Deep blue-grey / onyx layered surfaces
      surface: Color(0xFF111418),
      onSurface: Color(0xFFE8ECF0),

      surfaceContainerLowest: Color(0xFF181D23),
      surfaceContainerLow: Color(0xFF1A2027),
      surfaceContainer: Color(0xFF1E252D),
      surfaceContainerHigh: Color(0xFF272F39),
      surfaceContainerHighest: Color(0xFF323B46),

      onSurfaceVariant: Color(0xFFA7B1BC),
      outline: Color(0xFF68727E),
      outlineVariant: Color(0xFF2E3742),

      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),

      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE8ECF0),
      inversePrimary: Color(0xFFE88F1D),
    );
  }

  ThemeData dark() => theme(darkScheme());
  ThemeData light() => theme(lightScheme());

  ThemeData theme(ColorScheme colorScheme) {
    final primaryOnSurface = colorScheme.primaryOnSurface;
    final isLight = colorScheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,

      // Text Theme
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
        fontFamily: 'Signika',
      ),

      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,

      // 1. App Bar: Clean, flat, no Material3 tint shifting on scroll
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Signika',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.42),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Signika',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOnSurface,
          textStyle: const TextStyle(
            fontFamily: 'Signika',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOnSurface,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Signika',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primary.withValues(
          alpha: isLight ? 0.3 : 0.24,
        ),
        checkmarkColor: primaryOnSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 18),
        labelStyle: TextStyle(
          fontFamily: 'Signika',
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Signika',
          fontWeight: FontWeight.w700,
          color: primaryOnSurface,
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(
              color: primaryOnSurface.withValues(alpha: 0.45),
            );
          }
          return BorderSide(color: colorScheme.outlineVariant);
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primaryOnSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: primaryOnSurface,
        dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontFamily: 'Signika',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Signika',
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),

      // 3. Floating Action Button: Clean warm brand accent
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // 4. Input Fields: Crisp fill + hairline outline + warm orange focus border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            );
          }
          if (states.contains(WidgetState.error)) {
            if (states.contains(WidgetState.hovered)) {
              return TextStyle(color: colorScheme.onErrorContainer);
            }
            return TextStyle(color: colorScheme.error);
          }
          if (states.contains(WidgetState.focused)) {
            return TextStyle(
              color: primaryOnSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          );
        }),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        ),
        fillColor: isLight
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryOnSurface, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryOnSurface,
      ),

      // 5. Cards: Crisp elevated white on cool light canvas; subtle bordered slate in dark
      cardTheme: CardThemeData(
        elevation: isLight ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.08 : 0.0),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isLight ? 0.55 : 0.75,
            ),
          ),
        ),
        color: colorScheme.surfaceContainer,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        dragHandleColor: colorScheme.outlineVariant,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // 6. Selectors (Switches, Radios, Sliders) use the brand accent
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryOnSurface;
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: isLight ? 0.42 : 0.50);
          }
          return colorScheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return colorScheme.outlineVariant;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll(1.5),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryOnSurface,
        thumbColor: primaryOnSurface,
      ),

      // 7. Navigation: Material 3 NavigationBar and NavigationRail
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.26),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryOnSurface);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: primaryOnSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primary.withValues(
          alpha: isLight ? 0.30 : 0.26,
        ),
        selectedIconTheme: IconThemeData(color: primaryOnSurface, size: 22),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Signika',
          color: primaryOnSurface,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Signika',
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}
