import 'package:flutter/material.dart';

/// Motywy aplikacji (jasny / ciemny) oparte o Material 3.
class AppTheme {
  static const _seed = Color(0xFF2E6E4E);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
