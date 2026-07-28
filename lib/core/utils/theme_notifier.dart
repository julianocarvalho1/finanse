import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Classe que guarda o Estado completo do Tema (Cor + Modo Claro/Escuro)
class ThemeState {
  final Color color;
  final ThemeMode mode;

  ThemeState({required this.color, required this.mode});
}

class ThemeNotifier extends ValueNotifier<ThemeState> {
  // Padrão inicial: Verde e "Acompanhar o Sistema"
  ThemeNotifier()
    : super(
        ThemeState(color: const Color(0xFF22C55E), mode: ThemeMode.system),
      ) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final colorValue = prefs.getInt('themeColor');
    final modeString = prefs.getString('themeMode');

    Color loadedColor = const Color(0xFF22C55E);
    if (colorValue != null) loadedColor = Color(colorValue);

    ThemeMode loadedMode = ThemeMode.system;
    if (modeString == 'light') loadedMode = ThemeMode.light;
    if (modeString == 'dark') loadedMode = ThemeMode.dark;

    value = ThemeState(color: loadedColor, mode: loadedMode);
  }

  Future<void> updateColor(Color newColor) async {
    value = ThemeState(color: newColor, mode: value.mode); // Atualiza só a cor
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', newColor.toARGB32());
  }

  Future<void> updateMode(ThemeMode newMode) async {
    value = ThemeState(color: value.color, mode: newMode); // Atualiza só o modo
    final prefs = await SharedPreferences.getInstance();

    String modeString = 'system';
    if (newMode == ThemeMode.light) modeString = 'light';
    if (newMode == ThemeMode.dark) modeString = 'dark';

    await prefs.setString('themeMode', modeString);
  }
}

final themeNotifier = ThemeNotifier();
