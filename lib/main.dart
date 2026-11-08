import 'dart:async';

import 'package:flutter/material.dart';

import 'aplicativo.dart';
import 'dados/controlador_conta.dart';
import 'dados/biblioteca_acordes.dart';
import 'dados/repositorio_listas.dart';
import 'dados/repositorio_musicas.dart';
import 'dados/controlador_tema.dart';
import 'dados/repositorio_temas.dart';
import 'servicos/servico_sincronizacao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await SongRepository.open();
  final chords = await ChordLibrary.open();
  final account = await AccountController.open();
  final setlists = await SetlistRepository.open();
  final theme = await ThemeController.open();
  final musicThemes = await ThemeRepository.open();
  final sync = SyncService(repository, setlists, account, musicThemes: musicThemes);
  // Não bloqueia a abertura: o app funciona offline mesmo sem login.
  unawaited(account.restore());
  runApp(CifrasApp(
    repository: repository,
    chords: chords,
    account: account,
    sync: sync,
    setlists: setlists,
    theme: theme,
    musicThemes: musicThemes,
  ));
}
