import 'package:flutter/material.dart';

import '../models/settings.dart';

/// Colori del marchio Dom Studio.
class Brand {
  static const blue = Color(0xFF1D3A8A);
  static const orange = Color(0xFFF28C38);
  static const paper = Color(0xFFFFF8F0);
  static const ink = Color(0xFF14213D);
}

ThemeData _base(ColorScheme scheme, {Color? background}) {
  final bg = background ?? scheme.surface;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(surface: bg),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Sora',
        fontVariations: const [FontVariation('wght', 700)],
        fontSize: 20,
        color: scheme.onSurface,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Brand.orange,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

ThemeData lightTheme() => _base(
      ColorScheme.fromSeed(seedColor: Brand.blue, brightness: Brightness.light)
          .copyWith(primary: Brand.blue, secondary: Brand.orange, onSurface: Brand.ink),
      background: Colors.white,
    );

ThemeData darkTheme() => _base(
      ColorScheme.fromSeed(seedColor: Brand.blue, brightness: Brightness.dark)
          .copyWith(secondary: Brand.orange),
      background: const Color(0xFF0F1626),
    );

ThemeData sepiaTheme() => _base(
      ColorScheme.fromSeed(seedColor: const Color(0xFF8A5A1D), brightness: Brightness.light)
          .copyWith(
        primary: const Color(0xFF7A4E16),
        secondary: Brand.orange,
        onSurface: const Color(0xFF3B2A17),
        surfaceContainerHighest: const Color(0xFFEFE2CC),
        surfaceContainerHigh: const Color(0xFFF2E7D4),
        surfaceContainer: const Color(0xFFF5ECDC),
        surfaceContainerLow: const Color(0xFFF7F0E2),
      ),
      background: const Color(0xFFF8F1E3),
    );

(ThemeData, ThemeData?, ThemeMode) themesFor(AppTheme t) => switch (t) {
      AppTheme.system => (lightTheme(), darkTheme(), ThemeMode.system),
      AppTheme.light => (lightTheme(), null, ThemeMode.light),
      AppTheme.dark => (darkTheme(), null, ThemeMode.light),
      AppTheme.sepia => (sepiaTheme(), null, ThemeMode.light),
    };
