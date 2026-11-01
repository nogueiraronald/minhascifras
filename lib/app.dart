import 'package:flutter/material.dart';

import 'data/account_controller.dart';
import 'data/chord_library.dart';
import 'data/setlist_repository.dart';
import 'data/song_repository.dart';
import 'screens/song_list_screen.dart';
import 'services/sync_service.dart';

class CifrasApp extends StatelessWidget {
  const CifrasApp({
    super.key,
    required this.repository,
    required this.chords,
    required this.account,
    required this.sync,
    required this.setlists,
  });

  final SongRepository repository;
  final ChordLibrary chords;
  final AccountController account;
  final SyncService sync;
  final SetlistRepository setlists;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cifras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: SongListScreen(repository: repository, chords: chords, account: account, sync: sync, setlists: setlists),
    );
  }
}
