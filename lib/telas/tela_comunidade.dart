import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../componentes/botao_conta.dart';
import '../componentes/dialogo_acordes.dart';
import '../componentes/estilo_app.dart';
import '../componentes/logo_aplicativo.dart';
import '../componentes/visualizador_cifra.dart';
import '../componentes/visualizador_letra.dart';
import '../componentes/visualizador_partitura.dart';
import '../dados/biblioteca_acordes.dart';
import '../dados/controlador_conta.dart';
import '../dados/controlador_tema.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/musica.dart';
import '../modelos/musica_comunidade.dart';
import '../servicos/servico_comunidade.dart';
import '../servicos/servico_sincronizacao.dart';
import '../servicos/transpositor_acordes.dart';

/// Tela da Comunidade:
/// - Carrossel em destaque com as últimas cifras compartilhadas (ícone da música,
///   imagem opcional, nome da música, data da disponibilização e usuário que compartilhou).
/// - Compartilhamento de uma ou mais músicas da lista pessoal (exige e-mail, senha e nickname).
/// - Visualização online e importação para a lista pessoal do usuário.
class TelaComunidade extends StatefulWidget {
  const TelaComunidade({
    super.key,
    required this.repository,
    required this.chords,
    required this.account,
    required this.sync,
    required this.setlists,
    this.theme,
    this.communityService,
  });

  final SongRepository repository;
  final ChordLibrary chords;
  final AccountController account;
  final SyncService sync;
  final SetlistRepository setlists;
  final ThemeController? theme;
  final CommunityService? communityService;

  /// Fluxo unificado para compartilhar uma ou mais músicas na Comunidade
  /// (pode ser acionado tanto da tela Minhas Cifras quanto da tela Comunidade).
  static Future<List<CommunitySong>?> compartilharMusicas({
    required BuildContext context,
    required AccountController account,
    required SongRepository repository,
    required SyncService sync,
    CommunityService? communityService,
    List<String> initialSelectedSongIds = const [],
    List<CommunitySong>? existingCommunitySongs,
  }) async {
    final service = communityService ?? CommunityService();

    if (!account.canPostToCommunity) {
      final authenticated = await _showCommunityAuthDialogStatic(
        context: context,
        account: account,
        sync: sync,
      );
      if (authenticated != true || !context.mounted) return null;
    }

    if (!context.mounted) return null;
    return _showSelectSongsToShareDialogStatic(
      context: context,
      account: account,
      repository: repository,
      service: service,
      initialSelectedSongIds: initialSelectedSongIds,
      existingCommunitySongs: existingCommunitySongs,
    );
  }

  /// Modal de cadastro/autenticação com E-mail, Senha e Nickname obrigatório para postar na Comunidade.
  static Future<bool?> _showCommunityAuthDialogStatic({
    required BuildContext context,
    required AccountController account,
    required SyncService sync,
  }) {
    final emailCtrl = TextEditingController(text: account.userEmail ?? '');
    final passCtrl = TextEditingController();
    final nickCtrl = TextEditingController(text: account.userNickname ?? '');
    bool obscure = true;
    bool saving = false;
    String? localError;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: SingleChildScrollView(
              child: CartaoDialogoModerno(
                width: 440,
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BadgeIconeGradiente(
                          icon: Icons.verified_user_rounded,
                          size: 42,
                          iconSize: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identificação na Comunidade',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cadastre ou acesse com e-mail, senha e nickname para postar cifras',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('community_auth_email'),
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'ex: musico@email.com',
                        prefixIcon:
                            const Icon(Icons.alternate_email_rounded, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('community_auth_password'),
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('community_auth_nickname'),
                      controller: nickCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nickname (Apelido Público)',
                        hintText: 'ex: ronald_violao',
                        prefixIcon:
                            const Icon(Icons.person_outline_rounded, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          localError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        BotaoGradiente(
                          isLoading: saving,
                          onPressed: saving
                              ? null
                              : () async {
                                  final email = emailCtrl.text.trim();
                                  final pass = passCtrl.text.trim();
                                  final nick = nickCtrl.text
                                      .trim()
                                      .replaceFirst(RegExp(r'^@+'), '');

                                  if (email.isEmpty ||
                                      !email.contains('@') ||
                                      !email.contains('.')) {
                                    setModalState(() => localError =
                                        'Informe um e-mail válido.');
                                    return;
                                  }
                                  if (pass.isEmpty &&
                                      !account.isPasswordProtected) {
                                    setModalState(() => localError =
                                        'Informe uma senha para sua conta.');
                                    return;
                                  }
                                  if (nick.isEmpty) {
                                    setModalState(() => localError =
                                        'O nickname é obrigatório para postar na comunidade.');
                                    return;
                                  }

                                  setModalState(() {
                                    saving = true;
                                    localError = null;
                                  });

                                  try {
                                    if (pass.isNotEmpty) {
                                      await account.loginWithEmailAndPassword(
                                        emailInput: email,
                                        passwordInput: pass,
                                        nicknameInput: nick,
                                        onSync: () => sync.sync(),
                                      );
                                    } else {
                                      await account.setNickname(nick);
                                      await sync.sync();
                                    }
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx, true);
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setModalState(() {
                                        saving = false;
                                        localError = e.toString().replaceFirst(
                                            RegExp(
                                                r'^(Exception|FormatException|StateError):\s*'),
                                            '');
                                      });
                                    }
                                  }
                                },
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Continuar',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Modal para o usuário logado selecionar uma ou mais músicas da sua lista e imagem opcional para postar na Comunidade.
  static Future<List<CommunitySong>?> _showSelectSongsToShareDialogStatic({
    required BuildContext context,
    required AccountController account,
    required SongRepository repository,
    required CommunityService service,
    List<String> initialSelectedSongIds = const [],
    List<CommunitySong>? existingCommunitySongs,
  }) async {
    final userSongs = repository.songs;
    if (userSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sua lista "Minhas Cifras" está vazia. Cadastre uma música antes de compartilhar.'),
        ),
      );
      return null;
    }

    List<CommunitySong> currentCommunity = existingCommunitySongs ?? [];
    if (existingCommunitySongs == null) {
      try {
        currentCommunity = await service.fetchCommunitySongs();
      } catch (_) {
        currentCommunity = [];
      }
    }
    if (!context.mounted) return null;

    final userEmail = account.userEmail ?? '';
    CommunitySong? findShared(Song s) => service.findSharedSongByUser(
          song: s,
          userEmail: userEmail,
          communitySongs: currentCommunity,
        );

    // Filtra IDs iniciais para não marcar músicas que o usuário já compartilhou
    final selectedIds = <String>{
      for (final id in initialSelectedSongIds)
        if (userSongs.any((s) => s.id == id && findShared(s) == null)) id,
    };
    final imageUrlCtrl = TextEditingController();
    String filter = '';
    bool publishing = false;
    String? removingSongId;
    bool modifiedCommunity = false;
    String? dialogError;
    String? pickedImageDataUri;
    String? pickedImageName;

    return showDialog<List<CommunitySong>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final filtered = userSongs.where((s) {
            if (filter.isEmpty) return true;
            final q = filter.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();
          final selectableFiltered =
              filtered.where((s) => findShared(s) == null).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: SingleChildScrollView(
              child: CartaoDialogoModerno(
                width: 520,
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BadgeIconeGradiente(
                          icon: Icons.cloud_upload_rounded,
                          size: 42,
                          iconSize: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compartilhar na Comunidade',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Postando como @${account.userNickname}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppCores.roxo,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: publishing
                              ? null
                              : () => Navigator.pop(
                                    ctx,
                                    modifiedCommunity ? currentCommunity : null,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Campo de busca nas músicas do usuário
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Filtrar suas músicas por nome ou artista...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) =>
                          setModalState(() => filter = val.trim()),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Escolha uma ou mais músicas (${selectedIds.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectableFiltered.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              setModalState(() {
                                final allSelected = selectableFiltered
                                    .every((s) => selectedIds.contains(s.id));
                                if (allSelected) {
                                  selectedIds.clear();
                                } else {
                                  for (final s in selectableFiltered) {
                                    selectedIds.add(s.id);
                                  }
                                }
                              });
                            },
                            child: Text(
                              selectableFiltered.every(
                                          (s) => selectedIds.contains(s.id)) &&
                                      selectableFiltered.isNotEmpty
                                  ? 'Desmarcar todas'
                                  : 'Selecionar disponíveis',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),

                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Nenhuma música encontrada.'),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final s = filtered[i];
                                  final sharedEntry = findShared(s);
                                  final alreadyShared = sharedEntry != null;
                                  final checked =
                                      !alreadyShared && selectedIds.contains(s.id);

                                  if (alreadyShared) {
                                    final isRemoving = removingSongId == s.id;
                                    final impCount = sharedEntry.importCount;
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      leading: const Icon(
                                        Icons.cloud_done_rounded,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      title: Text(
                                        s.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        'Já compartilhada na comunidade • ${impCount == 1 ? "1 import" : "$impCount imports"}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: TextButton.icon(
                                        key: ValueKey(
                                            'btn_dialog_unshare_${s.id}'),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                        ),
                                        onPressed: isRemoving || publishing
                                            ? null
                                            : () async {
                                                setModalState(() {
                                                  removingSongId = s.id;
                                                  dialogError = null;
                                                });
                                                try {
                                                  final updated = await service
                                                      .unpublishSong(
                                                    target: sharedEntry,
                                                    userEmail: userEmail,
                                                  );
                                                  if (!ctx.mounted) return;
                                                  setModalState(() {
                                                    currentCommunity = updated;
                                                    removingSongId = null;
                                                    modifiedCommunity = true;
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '"${s.title}" removida do compartilhamento na comunidade.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (ctx.mounted) {
                                                    setModalState(() {
                                                      removingSongId = null;
                                                      dialogError = e
                                                          .toString()
                                                          .replaceFirst(
                                                              RegExp(
                                                                  r'^(Exception|FormatException):\s*'),
                                                              '');
                                                    });
                                                  }
                                                }
                                              },
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 16),
                                        label: Text(
                                          isRemoving ? '...' : 'Remover',
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                      ),
                                    );
                                  }

                                  return CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    value: checked,
                                    title: Text(
                                      s.title,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: s.artist.isNotEmpty
                                        ? Text(
                                            s.artist,
                                            style:
                                                const TextStyle(fontSize: 11.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    onChanged: (v) {
                                      setModalState(() {
                                        if (v == true) {
                                          selectedIds.add(s.id);
                                        } else {
                                          selectedIds.remove(s.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Imagem opcional da música
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('community_share_image_url'),
                            controller: imageUrlCtrl,
                            decoration: InputDecoration(
                              labelText: 'Imagem da música (URL opcional)',
                              hintText: 'https://exemplo.com/capa.jpg',
                              prefixIcon:
                                  const Icon(Icons.image_outlined, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            try {
                              final res = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              if (res != null &&
                                  res.files.isNotEmpty &&
                                  res.files.first.bytes != null) {
                                final file = res.files.first;
                                final ext =
                                    (file.extension ?? 'png').toLowerCase();
                                final mime =
                                    ext == 'jpg' || ext == 'jpeg'
                                        ? 'image/jpeg'
                                        : 'image/png';
                                final b64 = base64Encode(file.bytes!);
                                setModalState(() {
                                  pickedImageDataUri = 'data:$mime;base64,$b64';
                                  pickedImageName = file.name;
                                });
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 17),
                          label: Text(
                            pickedImageName != null ? 'Foto OK' : 'Arquivo',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: publishing
                              ? null
                              : () => Navigator.pop(
                                    ctx,
                                    modifiedCommunity ? currentCommunity : null,
                                  ),
                          child: const Text('Fechar'),
                        ),
                        const SizedBox(width: 8),
                        BotaoGradiente(
                          isLoading: publishing,
                          onPressed: publishing || selectedIds.isEmpty
                              ? null
                              : () async {
                                  setModalState(() {
                                    publishing = true;
                                    dialogError = null;
                                  });
                                  try {
                                    final chosenSongs = userSongs
                                        .where(
                                            (s) => selectedIds.contains(s.id))
                                        .toList();
                                    final img = pickedImageDataUri ??
                                        (imageUrlCtrl.text.trim().isNotEmpty
                                            ? imageUrlCtrl.text.trim()
                                            : null);
                                    final updated = await service.publishSongs(
                                      songs: chosenSongs,
                                      nickname: account.userNickname ?? '',
                                      email: account.userEmail ?? '',
                                      imageUrl: img,
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx, updated);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${chosenSongs.length} cifra(s) compartilhada(s) na Comunidade com sucesso!',
                                          ),
                                          backgroundColor: Colors.green[800],
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setModalState(() {
                                        publishing = false;
                                        dialogError = e
                                            .toString()
                                            .replaceFirst(
                                                RegExp(
                                                    r'^(Exception|FormatException):\s*'),
                                                '');
                                      });
                                    }
                                  }
                                },
                          icon: Icons.share_rounded,
                          label: 'Publicar (${selectedIds.length})',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  State<TelaComunidade> createState() => _TelaComunidadeState();
}

class _TelaComunidadeState extends State<TelaComunidade> {
  late final CommunityService _service =
      widget.communityService ?? CommunityService();

  final TextEditingController _searchCtrl = TextEditingController();
  final PageController _carouselCtrl = PageController();

  List<CommunitySong> _communitySongs = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchCtrl.text.trim().toLowerCase();
        });
      }
    });
    _loadOnlineCommunitySongs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _carouselCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineCommunitySongs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.fetchCommunitySongs();
      if (!mounted) return;
      setState(() {
        _communitySongs = list;
        _loading = false;
        _carouselIndex = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Não foi possível acessar a comunidade online no momento. Verifique sua conexão e tente novamente.';
      });
    }
  }

  bool _isAlreadyInUserList(Song communitySong) {
    final key = SongRepository.normKey(communitySong.title, communitySong.artist);
    return widget.repository.songs
        .any((s) => SongRepository.normKey(s.title, s.artist) == key);
  }

  Future<void> _importSong(CommunitySong item) async {
    await _service.importSongToUserList(
      communitySong: item,
      repository: widget.repository,
    );
    try {
      final refreshed = await _service.fetchCommunitySongs();
      if (mounted) {
        setState(() {
          _communitySongs = refreshed;
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${item.song.title}" importada para Minhas Cifras com sucesso!',
        ),
        backgroundColor: Colors.green[800],
      ),
    );
  }

  bool _isSharedByCurrentUser(CommunitySong item) {
    final myEmail = widget.account.userEmail?.trim().toLowerCase() ?? '';
    return myEmail.isNotEmpty &&
        item.sharedByEmail.trim().toLowerCase() == myEmail;
  }

  Future<void> _unpublishCommunitySong(CommunitySong item) async {
    final myEmail = widget.account.userEmail?.trim() ?? '';
    if (myEmail.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover do compartilhamento?'),
        content: Text(
          'Deseja remover "${item.song.title}" da exibição na Comunidade?\n\n'
          'Os usuários que já importaram esta cifra continuarão com ela normalmente em suas listas pessoais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updated = await _service.unpublishSong(
        target: item,
        userEmail: myEmail,
      );
      if (!mounted) return;
      setState(() {
        _communitySongs = updated;
        _carouselIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${item.song.title}" foi removida do compartilhamento na comunidade.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^(Exception|FormatException):\s*'), ''),
          ),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  /// Abre o leitor online de uma cifra da comunidade (sem baixar automaticamente para a biblioteca local).
  void _openOnlineSongReader(CommunitySong item, [List<CommunitySong>? listContext]) {
    final songs = (listContext != null && listContext.isNotEmpty)
        ? listContext
        : (_communitySongs.isNotEmpty ? _communitySongs : [item]);
    final initialIdx = songs.indexWhere((c) => c.id == item.id);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _TelaLeitorComunidadeOnline(
          songs: songs,
          initialIndex: initialIdx >= 0 ? initialIdx : 0,
          chords: widget.chords,
          repository: widget.repository,
          onImport: (commSong) => _importSong(commSong),
          isAlreadyImported: (song) => _isAlreadyInUserList(song),
        ),
      ),
    );
  }

  /// Renderiza a miniatura / capa da música com ícone da música e imagem opcional do usuário
  Widget _buildSongArtwork(
    CommunitySong item, {
    double size = 64,
    double borderRadius = 16,
  }) {
    final imageUrl = item.imageUrl?.trim();

    Widget fallbackIcon() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppCores.gradienteLogo,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppCores.roxo.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: size * 0.48,
          ),
        ),
      );
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return fallbackIcon();
    }

    Widget imageWidget;
    if (imageUrl.startsWith('data:image')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final b64 =
            commaIdx >= 0 ? imageUrl.substring(commaIdx + 1) : imageUrl;
        final bytes = base64Decode(b64);
        imageWidget = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackIcon(),
        );
      } catch (_) {
        return fallbackIcon();
      }
    } else {
      imageWidget = Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallbackIcon(),
      );
    }

    // Exibe a imagem colocada pelo usuário junto com o badge do ícone da música
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: imageWidget,
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppCores.gradienteLogo,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: (size * 0.22).clamp(11.0, 16.0),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(
    CommunitySong item,
    bool isDark,
    bool isMobile,
    List<CommunitySong> listContext,
  ) {
    final alreadyImported = _isAlreadyInUserList(item.song);
    final isMine = _isSharedByCurrentUser(item);

    return Container(
      key: ValueKey('carousel_card_${item.id}'),
      decoration: BoxDecoration(
        gradient: AppCores.gradienteTranslucido(isDark),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppCores.roxo.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppCores.roxo.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openOnlineSongReader(item, listContext),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 9 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildSongArtwork(
                    item,
                    size: isMobile ? 36 : 44,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.song.title,
                          style: TextStyle(
                            fontSize: isMobile ? 12.5 : 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.song.artist.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            item.song.artist,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: AppCores.roxo,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '@${item.sharedByNickname}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppCores.roxo,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 10.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.importCount > 0
                          ? '${item.formattedDate} • ${item.importCount} import(s)'
                          : item.formattedDate,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  if (!alreadyImported) ...[
                    IconButton(
                      tooltip: 'Visualizar cifra',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: AppCores.roxo,
                      ),
                      onPressed: () => _openOnlineSongReader(item, listContext),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppCores.gradienteBotao,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppCores.roxo.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _importSong(item),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    size: 13.5,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Importar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Cifra já presente na lista do usuário: botão limpo e elegante de Visualizar com gradiente oficial
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppCores.gradienteBotao,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppCores.roxo.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () =>
                                _openOnlineSongReader(item, listContext),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Visualizar',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isMine) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      key: ValueKey('btn_carousel_unshare_${item.id}'),
                      tooltip: 'Remover do compartilhamento',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _unpublishCommunitySong(item),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói o Carrossel de Últimas Cifras Compartilhadas:
  /// - Limitado estritamente aos 10 últimos compartilhamentos.
  /// - Exibe 2 cards por vez em telas pequenas (< 800px) e 4 cards por vez em telas grandes (>= 800px).
  Widget _buildLatestCarousel(
    bool isDark,
    bool isMobile,
    double screenWidth,
  ) {
    final latest =
        _communitySongs.take(CommunityService.maxCarouselItems).toList();
    if (latest.isEmpty) return const SizedBox.shrink();

    final itemsPerPage = screenWidth < 800 ? 2 : 4;
    final totalPages = (latest.length / itemsPerPage).ceil();
    final safePage = _carouselIndex.clamp(0, totalPages - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppCores.roxo, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Últimas Cifras Compartilhadas',
                  style: TextStyle(
                    fontSize: isMobile ? 15.5 : 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (totalPages > 1) ...[
                IconButton(
                  tooltip: 'Anterior',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: safePage > 0
                      ? () {
                          _carouselCtrl.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      : null,
                ),
                Text(
                  '${safePage + 1}/$totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                IconButton(
                  tooltip: 'Próxima',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: safePage < totalPages - 1
                      ? () {
                          _carouselCtrl.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: isMobile ? 156 : 162,
          child: PageView.builder(
            key: const ValueKey('community_latest_carousel'),
            controller: _carouselCtrl,
            itemCount: totalPages,
            onPageChanged: (idx) => setState(() => _carouselIndex = idx),
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * itemsPerPage;
              final gap = isMobile ? 8.0 : 12.0;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 24,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    for (int slot = 0; slot < itemsPerPage; slot++) ...[
                      if (slot > 0) SizedBox(width: gap),
                      Expanded(
                        child: (startIndex + slot) < latest.length
                            ? _buildCarouselCard(
                                latest[startIndex + slot],
                                isDark,
                                isMobile,
                                latest,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;

    final filtered = _communitySongs.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.song.title.toLowerCase().contains(_searchQuery) ||
          item.song.artist.toLowerCase().contains(_searchQuery) ||
          item.sharedByNickname.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListenableBuilder(
      listenable: Listenable.merge([widget.account, widget.repository]),
      builder: (context, _) {
        return Scaffold(
          key: const ValueKey('community_screen_scaffold'),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 12,
            title: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  BotaoVoltarInicio(
                    iconSize: 24,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AppLogo(
                    compact: false,
                    iconSize: 24,
                    onTap: Navigator.canPop(context)
                        ? () => Navigator.maybePop(context)
                        : null,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Atualizar cifras da comunidade',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _loading ? null : _loadOnlineCommunitySongs,
              ),
              if (widget.theme != null)
                IconButton(
                  tooltip: widget.theme!.isDark(context)
                      ? 'Modo Claro'
                      : 'Modo Escuro',
                  icon: Icon(
                    widget.theme!.isDark(context)
                        ? Icons.light_mode
                        : Icons.dark_mode_outlined,
                    size: 20,
                  ),
                  onPressed: () => widget.theme!.toggle(context),
                ),
              AccountButton(
                account: widget.account,
                songs: widget.repository,
                setlists: widget.setlists,
                sync: widget.sync,
                compact: isMobile,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner elegante da Comunidade (apenas consumo das cifras compartilhadas)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 24,
                    vertical: isMobile ? 10 : 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppCores.gradienteTranslucido(isDark),
                    border: Border(
                      bottom: BorderSide(
                        color: AppCores.roxo.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Icon(Icons.public_rounded,
                              color: AppCores.roxo, size: 20),
                          Text(
                            'Comunidade MinhasCifras',
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 19,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.account.canPostToCommunity
                            ? 'Olá, @${widget.account.userNickname}! Explore os arranjos compartilhados pela comunidade e importe para sua lista.'
                            : 'Um espaço colaborativo feito por músicos e para músicos. Explore arranjos e descubra novas canções.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _loading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Carregando cifras da comunidade...',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.wifi_off_rounded,
                                      size: 48,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    BotaoGradiente(
                                      onPressed: _loadOnlineCommunitySongs,
                                      icon: Icons.refresh_rounded,
                                      label: 'Tentar Novamente',
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _communitySongs.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const BadgeIconeGradiente(
                                          icon: Icons.groups_rounded,
                                          size: 58,
                                          iconSize: 30,
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Nenhuma cifra compartilhada ainda',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'As cifras compartilhadas pelos músicos através do menu em "Minhas Cifras" aparecerão aqui.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : CustomScrollView(
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 12),
                                        child: _buildLatestCarousel(
                                            isDark, isMobile, width),
                                      ),
                                    ),
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          isMobile ? 14 : 24,
                                          14,
                                          isMobile ? 14 : 24,
                                          8,
                                        ),
                                        child: TextField(
                                          controller: _searchCtrl,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Pesquisar na comunidade por música, artista ou @usuário...',
                                            prefixIcon: const Icon(
                                                Icons.search_rounded,
                                                size: 18),
                                            suffixIcon:
                                                _searchQuery.isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(
                                                            Icons.clear_rounded,
                                                            size: 18),
                                                        onPressed: () =>
                                                            _searchCtrl.clear(),
                                                      )
                                                    : null,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 11),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SliverPadding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 14 : 24,
                                        vertical: 8,
                                      ),
                                      sliver: SliverList.separated(
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final item = filtered[index];
                                          final alreadyImported =
                                              _isAlreadyInUserList(item.song);
                                          final isMine =
                                              _isSharedByCurrentUser(item);

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white10
                                                    : Colors.black12,
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                              leading: _buildSongArtwork(
                                                item,
                                                size: 46,
                                                borderRadius: 12,
                                              ),
                                              title: Text(
                                                item.song.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Text(
                                                '${item.song.artist.isNotEmpty ? "${item.song.artist} • " : ""}Por @${item.sharedByNickname} em ${item.formattedDate}${item.importCount > 0 ? " • ${item.importCount} import(s)" : ""}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip:
                                                        'Visualizar cifra',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    icon: const Icon(
                                                      Icons.visibility_outlined,
                                                      color: AppCores.roxo,
                                                    ),
                                                    onPressed: () =>
                                                        _openOnlineSongReader(
                                                            item, filtered),
                                                  ),
                                                  if (!alreadyImported)
                                                    IconButton(
                                                      tooltip:
                                                          'Importar para Minhas Cifras',
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      icon: const Icon(
                                                        Icons
                                                            .download_for_offline_rounded,
                                                        color: AppCores.roxo,
                                                      ),
                                                      onPressed: () =>
                                                          _importSong(item),
                                                    ),
                                                  if (isMine)
                                                    IconButton(
                                                      key: ValueKey(
                                                          'btn_list_unshare_${item.id}'),
                                                      tooltip:
                                                          'Remover do compartilhamento',
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed: () =>
                                                          _unpublishCommunitySong(
                                                              item),
                                                    ),
                                                ],
                                              ),
                                              onTap: () =>
                                                  _openOnlineSongReader(
                                                      item, filtered),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Visualizador online de cifra da Comunidade (permite ler, transpor, ver acordes e importar).
class _TelaLeitorComunidadeOnline extends StatefulWidget {
  const _TelaLeitorComunidadeOnline({
    this.songs = const [],
    this.initialIndex = 0,
    required this.chords,
    required this.repository,
    required this.onImport,
    required this.isAlreadyImported,
  });

  final List<CommunitySong> songs;
  final int initialIndex;
  final ChordLibrary chords;
  final SongRepository repository;
  final Future<void> Function(CommunitySong item) onImport;
  final bool Function(Song song) isAlreadyImported;

  @override
  State<_TelaLeitorComunidadeOnline> createState() =>
      _TelaLeitorComunidadeOnlineState();
}

class _TelaLeitorComunidadeOnlineState
    extends State<_TelaLeitorComunidadeOnline> {
  late final List<CommunitySong> _songList;
  late int _currentIndex;
  final FocusNode _readerFocusNode =
      FocusNode(debugLabel: "CommunityReaderFocus");
  final ScrollController _scrollController = ScrollController();
  int _transpose = 0;
  double _fontSize = 17;
  double _speed = 20;
  bool _isPlaying = false;
  Timer? _scrollTimer;
  int _modeIndex = 0; // 0 = Cifra, 1 = Letra, 2 = Partitura
  bool _importing = false;
  int _navDirection = 1;
  double _horizontalDragDistance = 0;

  CommunitySong get _currentCommunitySong =>
      _songList[_currentIndex.clamp(0, _songList.length - 1)];

  @override
  void initState() {
    super.initState();
    _songList = List<CommunitySong>.from(widget.songs);
    _currentIndex = _songList.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _songList.length - 1);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _readerFocusNode.dispose();
    super.dispose();
  }

  void _navigateSong(int delta) {
    if (_songList.isEmpty) return;
    final next = _currentIndex + delta;
    if (next >= 0 && next < _songList.length) {
      _stopScroll();
      setState(() {
        _navDirection = delta;
        _currentIndex = next;
        _transpose = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  void _startScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scrollController.hasClients ||
          _scrollController.positions.length != 1) {
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      final next = _scrollController.offset + _speed * 0.05;
      if (next >= max) {
        _scrollController.jumpTo(max);
        _stopScroll();
      } else {
        _scrollController.jumpTo(next);
      }
    });
    setState(() => _isPlaying = true);
  }

  void _stopScroll() {
    _scrollTimer?.cancel();
    if (mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSpeedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return CartaoDialogoModerno(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BadgeIconeGradiente(
                      icon: Icons.speed_rounded,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Velocidade da Rolagem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ajuste o ritmo do rolamento automático',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppCores.gradienteBotao.createShader(bounds),
                    child: Text(
                      '${_speed.toInt()} px/s',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Slider(
                  activeColor: AppCores.roxo,
                  inactiveColor: AppCores.roxo.withValues(alpha: 0.2),
                  focusNode: FocusNode(canRequestFocus: false),
                  value: _speed,
                  min: 5,
                  max: 120,
                  onChanged: (v) {
                    setDialogState(() {});
                    setState(() => _speed = v);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Lenta (15)'),
                      selected: (_speed.toInt() == 15),
                      selectedColor: AppCores.roxo.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setDialogState(() {});
                        setState(() => _speed = 15);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Média (35)'),
                      selected: (_speed.toInt() == 35),
                      selectedColor: AppCores.roxo.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setDialogState(() {});
                        setState(() => _speed = 35);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Rápida (65)'),
                      selected: (_speed.toInt() == 65),
                      selectedColor: AppCores.roxo.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setDialogState(() {});
                        setState(() => _speed = 65);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BotaoGradiente(
                      onPressed: () => Navigator.pop(ctx),
                      label: 'Concluir',
                      icon: Icons.check_rounded,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) _navigateSong(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) _navigateSong(-1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) _scrollBy(180);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) _scrollBy(-180);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.pageDown) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) _scrollBy(350);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.pageUp) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) _scrollBy(-350);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (_isPlaying) {
          _stopScroll();
        } else {
          _scrollBy(220);
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_songList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comunidade')),
        body: const Center(child: Text('Nenhuma cifra para exibir.')),
      );
    }

    final currentItem = _currentCommunitySong;
    final song = currentItem.song;
    final alreadyImported = widget.isAlreadyImported(song);

    final detectedKey = ChordTransposer.detectKey(song.content) ??
        (song.originalKey.isNotEmpty ? song.originalKey : null);
    final displayKey = detectedKey != null
        ? ChordTransposer.transposeChord(detectedKey, _transpose)
        : 'Tom';

    return Focus(
      focusNode: _readerFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${song.artist.isNotEmpty ? "${song.artist} • " : ""}Por @${currentItem.sharedByNickname} em ${currentItem.formattedDate}',
                style: const TextStyle(fontSize: 11, color: AppCores.roxo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            if (!alreadyImported)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: BotaoGradiente(
                  isLoading: _importing,
                  onPressed: _importing
                      ? null
                      : () async {
                          setState(() => _importing = true);
                          await widget.onImport(currentItem);
                          if (mounted) {
                            setState(() => _importing = false);
                          }
                        },
                  icon: Icons.download_rounded,
                  label: 'Importar Cifra',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Barra de Modos de Visualização: [ Cifra | Letra | Partitura ]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 30,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(0, 'Cifra', Icons.music_note),
                        _buildModeButton(1, 'Letra', Icons.text_snippet_outlined),
                        _buildModeButton(2, 'Partitura', Icons.auto_stories_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Área de Leitura Central com gesto de arrastar para os lados
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _horizontalDragDistance = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _horizontalDragDistance += details.primaryDelta ?? 0;
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (_horizontalDragDistance < -50 || velocity < -250) {
                    _navigateSong(1);
                  } else if (_horizontalDragDistance > 50 || velocity > 250) {
                    _navigateSong(-1);
                  }
                  _horizontalDragDistance = 0;
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: Offset(_navDirection >= 0 ? 0.08 : -0.08, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('${currentItem.id}_$_modeIndex'),
                    child: _modeIndex == 0
                        ? ChordSheetView(
                            content: song.content,
                            transpose: _transpose,
                            fontSize: _fontSize,
                            controller: _scrollController,
                            onChordTap: (chord) =>
                                showChordDialog(context, widget.chords, chord),
                          )
                        : _modeIndex == 1
                            ? LyricsView(
                                content: song.content,
                                fontSize: _fontSize,
                                controller: _scrollController,
                              )
                            : ScoreSheetView(
                                content: song.content,
                                transpose: _transpose,
                                fontSize: _fontSize,
                                controller: _scrollController,
                                onChordTap: (chord) =>
                                    showChordDialog(context, widget.chords, chord),
                              ),
                  ),
                ),
              ),
            ),

            // Barra inferior com padrão visual padrão idêntico ao do MainScreen
            Focus(
              canRequestFocus: false,
              descendantsAreFocusable: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;

                      // Pílula do Tom
                      Widget buildToneControl({bool isExpanded = false}) {
                        final content = Row(
                          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
                          mainAxisAlignment: isExpanded
                              ? MainAxisAlignment.spaceBetween
                              : MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Diminuir meio tom',
                              icon: const Icon(Icons.remove_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 38, minHeight: 38),
                              onPressed: () => setState(() => _transpose--),
                            ),
                            InkWell(
                              onTap: _transpose != 0
                                  ? () => setState(() => _transpose = 0)
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (displayKey != 'Tom')
                                      Text(
                                        'Tom ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    Text(
                                      displayKey,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: _transpose != 0
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                      ),
                                    ),
                                    if (_transpose != 0) ...[
                                      const SizedBox(width: 3),
                                      Text(
                                        _transpose > 0
                                            ? '(+$_transpose)'
                                            : '($_transpose)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Aumentar meio tom',
                              icon: const Icon(Icons.add_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 38, minHeight: 38),
                              onPressed: () => setState(() => _transpose++),
                            ),
                          ],
                        );

                        return Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.25)),
                          ),
                          child: isExpanded
                              ? content
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: content,
                                ),
                        );
                      }

                      // Pílula da Fonte
                      Widget buildFontControl({bool isExpanded = false}) {
                        final content = Row(
                          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
                          mainAxisAlignment: isExpanded
                              ? MainAxisAlignment.spaceBetween
                              : MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Diminuir fonte',
                              icon: const Icon(Icons.remove_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 38, minHeight: 38),
                              onPressed: () => setState(() =>
                                  _fontSize = (_fontSize - 1).clamp(10.0, 36.0)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.format_size_rounded,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_fontSize.toInt()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Aumentar fonte',
                              icon: const Icon(Icons.add_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 38, minHeight: 38),
                              onPressed: () => setState(() =>
                                  _fontSize = (_fontSize + 1).clamp(10.0, 36.0)),
                            ),
                          ],
                        );

                        return Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.25)),
                          ),
                          child: isExpanded
                              ? content
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: content,
                                ),
                        );
                      }

                      // Passador de músicas
                      final songNav = Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Música anterior (Seta ← ou Pedal)',
                              icon: const Icon(Icons.skip_previous_rounded,
                                  size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 38, minHeight: 38),
                              onPressed: _currentIndex > 0
                                  ? () => _navigateSong(-1)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${_currentIndex + 1}/${_songList.length}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Próxima música (Seta → ou Pedal)',
                              icon: const Icon(Icons.skip_next_rounded, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 38, minHeight: 38),
                              onPressed: _currentIndex < _songList.length - 1
                                  ? () => _navigateSong(1)
                                  : null,
                            ),
                          ],
                        ),
                      );

                      // Rolagem automática
                      Widget buildAutoScroll({bool showSlider = true}) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filled(
                              tooltip: _isPlaying
                                  ? 'Pausar rolagem'
                                  : 'Iniciar rolagem automática',
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 22,
                              ),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: _isPlaying ? _stopScroll : _startScroll,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Rolar para cima (Seta ↑ ou Pedal)',
                              icon: const Icon(Icons.keyboard_arrow_up_rounded,
                                  size: 24),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 38),
                              onPressed: () => _scrollBy(-180),
                            ),
                            IconButton(
                              tooltip: 'Rolar para baixo (Seta ↓ ou Pedal)',
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 24),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 38),
                              onPressed: () => _scrollBy(180),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message:
                                  'Velocidade da rolagem (${_speed.toInt()} px/s) - Toque para ajustar',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(19),
                                onTap: _showSpeedDialog,
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(19),
                                    border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.speed_rounded,
                                          size: 16, color: Colors.indigo),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_speed.toInt()}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (showSlider) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: Slider(
                                  focusNode: FocusNode(canRequestFocus: false),
                                  value: _speed,
                                  min: 5,
                                  max: 120,
                                  onChanged: (v) => setState(() => _speed = v),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      if (isNarrow) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: songNav,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: buildAutoScroll(showSlider: false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: buildToneControl(isExpanded: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: buildFontControl(isExpanded: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  songNav,
                                  const SizedBox(width: 12),
                                  buildAutoScroll(showSlider: true),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              buildToneControl(isExpanded: false),
                              const SizedBox(width: 12),
                              buildFontControl(isExpanded: false),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(int index, String label, IconData icon) {
    final isSelected = _modeIndex == index;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => setState(() => _modeIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
