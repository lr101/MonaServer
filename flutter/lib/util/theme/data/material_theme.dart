import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,

      // PRIMARY: Your Original Orange (The Star)
      primary: Color(0xFFFFB77C),
      onPrimary: Color(0xFF4B2800),
      primaryContainer: Color(0xFFE88F1D),
      onPrimaryContainer: Color(0xFF000000),

      // SECONDARY: Slate Blue (Cool, technical contrast)
      secondary: Color(0xFF37474F), 
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFCFD8DC),
      onSecondaryContainer: Color(0xFF101D24),

      // TERTIARY: Muted Teal (Subtle accent)
      tertiary: Color(0xFF006978),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFB2EBF2),
      onTertiaryContainer: Color(0xFF001F24),

      // SURFACES: Cool Grey/White (No brown/beige)
      surface: Color(0xFFF4F6F8), 
      onSurface: Color(0xFF191C20),
      onSurfaceVariant: Color(0xFF454746),

      outline: Color(0xFF747775),
      outlineVariant: Color(0xFFC4C7C5),

      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),

      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF2E3132),
      inversePrimary: Color(0xFFFFB77C),
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,

      // PRIMARY: Lightened Orange for dark mode visibility
      primary: Color(0xFFFFB77C),
      onPrimary: Color(0xFF4B2800),
      primaryContainer: Color(0xFFE88F1D),
      onPrimaryContainer: Color(0xFF000000),

      // SECONDARY: Blue-Grey (Keeps it clean)
      secondary: Color(0xFFB0BEC5),
      onSecondary: Color(0xFF263238),
      secondaryContainer: Color(0xFF37474F),
      onSecondaryContainer: Color(0xFFECEFF1),

      // TERTIARY: Cyan accent
      tertiary: Color(0xFF4DD0E1),
      onTertiary: Color(0xFF00363D),
      tertiaryContainer: Color(0xFF004F58),
      onTertiaryContainer: Color(0xFF97F0FF),

      // SURFACES: Deep Blue-Grey / Gunmetal (The "Onyx" look)
      surface: Color(0xFF121519), 
      onSurface: Color(0xFFE1E2E4), // Cool white text
      
      // slightly lighter blue-grey for cards/inputs
      surfaceContainerLowest: Color(0xFF0C0E11),
      surfaceContainerLow: Color(0xFF1A1D21),
      surfaceContainer: Color(0xFF1E242B), 
      surfaceContainerHigh: Color(0xFF282E35),
      surfaceContainerHighest: Color(0xFF333A42),
      
      onSurfaceVariant: Color(0xFFC4C7C5),
      outline: Color(0xFF8E918F),
      outlineVariant: Color(0xFF444746),

      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),

      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE1E2E4),
      inversePrimary: Color(0xFFE88F1D),
    );
  }

  ThemeData dark() => theme(darkScheme());
  ThemeData light() => theme(lightScheme());

  ThemeData theme(ColorScheme colorScheme) {
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

      // --------------------------------------------------------
      // COMPONENT STYLING
      // --------------------------------------------------------

      // 1. App Bar: Clean, transparent-ish to show the surface color
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),

      // 3. Floating Action Button: Orange
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),

      // 4. Input Fields: Blue-Grey background with Orange focus border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Uses the container color (Dark Grey-Blue in dark mode, Light Grey in light mode)
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        // When focused, the border becomes Orange
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // 5. Cards: Subtle borders, using the "Container" color for depth
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        color: colorScheme.surfaceContainer, // Lighter than background
      ),
      
      // 6. Selectors (Switches, Radios, Sliders) use the Primary (Orange)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary.withValues(alpha: 0.5);
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
      ),

      // 7. Navigation: Material 3 NavigationBar and NavigationRail
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}
