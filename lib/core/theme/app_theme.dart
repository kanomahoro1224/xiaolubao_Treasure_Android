import 'package:flutter/material.dart';

class KafunoColors {
  const KafunoColors._();

  static const pink = Color(0xFFFFC0CB);
  static const secondary = Color(0xFF86868B);
  static const backgroundLight = Color(0xFFF1F3F5);
  static const backgroundDark = Color(0xFF121212);
}

class KafunoTheme {
  const KafunoTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KafunoColors.pink,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: KafunoColors.pink,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: KafunoColors.backgroundLight,
      fontFamily: 'Roboto',
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KafunoColors.pink,
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1C1E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: KafunoColors.pink,
        surface: const Color(0xFF1C1C1E),
      ),
      scaffoldBackgroundColor: KafunoColors.backgroundDark,
      fontFamily: 'Roboto',
    );
  }
}
