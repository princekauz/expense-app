import 'package:flutter/material.dart';

/// 6 themes — accessible contrast, distinguishable hue sets.
class AppThemes {
  static const List<BoardTheme> all = [
    BoardTheme(
      name: 'Classic White',
      seed: Color(0xFF1F5E5B), // teal (matches app icon)
      scaffold: Color(0xFFFAFAFA),
      surface: Colors.white,
      onSurface: Color(0xFF111111),
      accent: Color(0xFF1F5E5B),
      divider: Color(0xFF111111),
    ),
    BoardTheme(
      name: 'Midnight',
      seed: Color(0xFF8AB4F8),
      scaffold: Color(0xFF0F1115),
      surface: Color(0xFF1A1D24),
      onSurface: Color(0xFFEDEDED),
      accent: Color(0xFF8AB4F8),
      divider: Color(0xFFEDEDED),
    ),
    BoardTheme(
      name: 'Pastel',
      seed: Color(0xFFE91E63),
      scaffold: Color(0xFFFFF4F6),
      surface: Color(0xFFFFE4EC),
      onSurface: Color(0xFF2B2B2B),
      accent: Color(0xFFE91E63),
      divider: Color(0xFF2B2B2B),
    ),
    BoardTheme(
      name: 'Forest',
      seed: Color(0xFF2E7D32),
      scaffold: Color(0xFFF1F8E9),
      surface: Color(0xFFE8F5E9),
      onSurface: Color(0xFF1B5E20),
      accent: Color(0xFF2E7D32),
      divider: Color(0xFF1B5E20),
    ),
    BoardTheme(
      name: 'Sunset',
      seed: Color(0xFFFF6F00),
      scaffold: Color(0xFFFFF3E0),
      surface: Color(0xFFFFE0B2),
      onSurface: Color(0xFF3E2723),
      accent: Color(0xFFFF6F00),
      divider: Color(0xFF3E2723),
    ),
    BoardTheme(
      name: 'Slate',
      seed: Color(0xFF455A64),
      scaffold: Color(0xFFECEFF1),
      surface: Color(0xFFCFD8DC),
      onSurface: Color(0xFF263238),
      accent: Color(0xFF455A64),
      divider: Color(0xFF263238),
    ),
  ];

  static BoardTheme byIndex(int i) => all[i.clamp(0, all.length - 1)];

  static ThemeData materialThemeFor(int i) {
    final t = byIndex(i);
    final scheme = ColorScheme.fromSeed(
        seedColor: t.seed,
        brightness: t.isDark ? Brightness.dark : Brightness.light);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: t.scaffold,
    );
  }
}

class BoardTheme {
  final String name;
  final Color seed;
  final Color scaffold;
  final Color surface;
  final Color onSurface;
  final Color accent;
  final Color divider;

  const BoardTheme({
    required this.name,
    required this.seed,
    required this.scaffold,
    required this.surface,
    required this.onSurface,
    required this.accent,
    required this.divider,
  });

  bool get isDark => scaffold.computeLuminance() < 0.3;
}

/// 3 visual styles — affect row separation & total emphasis.
enum BoardStyle { ruled, boxed, minimal }

extension BoardStyleX on BoardStyle {
  String get label {
    switch (this) {
      case BoardStyle.ruled:
        return 'Ruled';
      case BoardStyle.boxed:
        return 'Boxed';
      case BoardStyle.minimal:
        return 'Minimal';
    }
  }
}

class AppCategories {
  static const List<String> presets = [
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Other'
  ];
}

class CategoryColors {
  static const Map<String, Color> map = {
    'Food': Color(0xFFFFA726),
    'Travel': Color(0xFF42A5F5),
    'Bills': Color(0xFFEF5350),
    'Shopping': Color(0xFFAB47BC),
    'Other': Color(0xFF8D6E63),
  };

  static Color of(String name) => map[name] ?? const Color(0xFF8D6E63);
}
