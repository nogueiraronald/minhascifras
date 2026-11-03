import 'package:cifras_app/dados/controlador_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeController toggles and persists theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = await ThemeController.open();

    expect(theme.themeMode, ThemeMode.system);

    await theme.setMode(ThemeMode.dark);
    expect(theme.themeMode, ThemeMode.dark);

    await theme.setMode(ThemeMode.light);
    expect(theme.themeMode, ThemeMode.light);
  });
}
