import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../dados/biblioteca_acordes.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/lista_repertorio.dart';
import '../componentes/dialogo_nome.dart';
import '../componentes/estilo_app.dart';
import 'tela_detalhe_lista.dart';

class SetlistsScreen extends StatelessWidget {
  const SetlistsScreen({
    super.key,
    required this.setlists,
    required this.songs,
    required this.chords,
  });

  final SetlistRepository setlists;
  final SongRepository songs;
  final ChordLibrary chords;

  Future<void> _create(BuildContext context) async {
    final name = await askName(context, title: 'Nova lista');
    if (name == null || name.isEmpty) return;
    await setlists.saveSetlist(Setlist(id: const Uuid().v4(), name: name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listas de Repertório')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Lista'),
        onPressed: () => _create(context),
      ),
      body: ListenableBuilder(
        listenable: setlists,
        builder: (context, _) {
          final lists = setlists.setlists;
          if (lists.isEmpty) {
            return const Center(
              child: Text('Nenhuma lista criada ainda.\nToque em "Nova Lista" para começar.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final s = lists[i];
              return Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) => showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return CartaoDialogoModerno(
                      width: 440,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.delete_forever_rounded,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Excluir Lista',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Esta ação não poderá ser desfeita.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              'Tem certeza que deseja excluir a lista "${s.name}"? As músicas da biblioteca não serão apagadas.',
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => Navigator.pop(ctx, true),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.delete_outline_rounded,
                                              size: 18, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            'Excluir Lista',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                onDismissed: (_) => setlists.removeSetlist(s.id),
                child: ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(s.name),
                  subtitle: Text('${setlists.countFor(s.id, songs.songs.map((e) => e.id))} músicas'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SetlistDetailScreen(
                          setlist: s, setlists: setlists, songs: songs, chords: chords),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
