import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/account_controller.dart';
import 'data/chord_library.dart';
import 'data/setlist_repository.dart';
import 'data/song_repository.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await SongRepository.open();
  final chords = await ChordLibrary.open();
  final account = await AccountController.open();
  final setlists = await SetlistRepository.open();
  final sync = SyncService(repository, setlists, account);
  // Não bloqueia a abertura: o app funciona offline mesmo sem login.
  unawaited(account.restore());
  runApp(CifrasApp(repository: repository, chords: chords, account: account, sync: sync, setlists: setlists));
}
