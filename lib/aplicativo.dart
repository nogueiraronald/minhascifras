import 'package:flutter/material.dart';

import 'dados/controlador_conta.dart';
import 'dados/biblioteca_acordes.dart';
import 'dados/repositorio_listas.dart';
import 'dados/repositorio_musicas.dart';
import 'dados/controlador_tema.dart';
import 'dados/repositorio_temas.dart';
import 'telas/tela_inicial.dart';
import 'servicos/servico_sincronizacao.dart';

class CifrasApp extends StatelessWidget {
  const CifrasApp({
    super.key,
    required this.repository,
    required this.chords,
    required this.account,
    required this.sync,
    required this.setlists,
    required this.musicThemes,
    this.theme,
  });

  final SongRepository repository;
  final ChordLibrary chords;
  final AccountController account;
  final SyncService sync;
  final SetlistRepository setlists;
  final ThemeRepository musicThemes;
  final ThemeController? theme;

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      colorSchemeSeed: const Color(0xFF7C3AED),
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        elevation: 10,
        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.25),
      ),
    );

    final darkTheme = ThemeData(
      colorSchemeSeed: const Color(0xFFA78BFA),
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardColor: const Color(0xFF1E293B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
        ),
        elevation: 10,
        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
      ),
    );

    Widget buildApp(ThemeMode mode) {
      return MaterialApp(
        title: 'MinhasCifras',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: mode,
        home: TelaInicial(
          repository: repository,
          chords: chords,
          account: account,
          sync: sync,
          setlists: setlists,
          musicThemes: musicThemes,
          theme: theme,
        ),
      );
    }

    if (theme != null) {
      return ListenableBuilder(
        listenable: theme!,
        builder: (context, _) => buildApp(theme!.themeMode),
      );
    }

    return buildApp(ThemeMode.system);
  }
}
