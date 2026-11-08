import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../dados/repositorio_musicas.dart';
import '../dados/repositorio_temas.dart';
import '../modelos/musica.dart';
import '../servicos/transpositor_acordes.dart';
import '../servicos/servico_importacao_cifra.dart';
import '../componentes/dialogo_importar_link.dart';
import '../componentes/estilo_app.dart';

class SongEditScreen extends StatefulWidget {
  const SongEditScreen({
    super.key,
    required this.repository,
    this.musicThemes,
    this.song,
  });

  final SongRepository repository;
  final ThemeRepository? musicThemes;
  final Song? song;

  @override
  State<SongEditScreen> createState() => _SongEditScreenState();
}

class _SongEditScreenState extends State<SongEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _content;
  late final TextEditingController _originalKey;
  late final TextEditingController _audioUrl;
  late final TextEditingController _audioDuration;
  late final FocusNode _titleFocusNode;
  late final FocusNode _artistFocusNode;
  late final FocusNode _keyFocusNode;
  late final FocusNode _contentFocusNode;
  late final FocusNode _audioFocusNode;
  final GlobalKey _audioKey = GlobalKey();
  final ScrollController _categoryBarScrollController = ScrollController();
  final ScrollController _chordBarScrollController = ScrollController();
  final ScrollController _minorChordBarScrollController = ScrollController();
  TextSelection _lastValidSelection = const TextSelection.collapsed(offset: 0);
  late bool _isFavorite;
  late List<String> _tags;
  String? _imageUrl;
  String? _imageFileName;
  bool _showChordBar = true;

  bool get _isEditing => widget.song != null;
  String _selectedChordCategory = 'Naturais';

  static const _majorNaturals = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const _minorNaturals = ['Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm'];
  static const _sevenths = [
    'C7', 'D7', 'E7', 'F7', 'G7', 'A7', 'B7',
    'C7M', 'G7M', 'D7M', 'A7M', 'Am7', 'Em7', 'Dm7', 'Bm7'
  ];
  static const _slashChords = [
    'D/F#', 'G/B', 'C/E', 'A/C#', 'E/G#', 'F/A', 'Am/G', 'C/G', 'D7/9'
  ];
  static const _accidentals = [
    'C#', 'Eb', 'F#', 'Ab', 'Bb',
    'C#m', 'F#m', 'G#m', 'Bbm', 'Ebm'
  ];

  static const _sectionTags = [
    '[Intro]',
    '[Primeira Parte]',
    '[Pré-Refrão]',
    '[Refrão]',
    '[Segunda Parte]',
    '[Ponte]',
    '[Solo]',
    '[Final]',
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.song?.title ?? '');
    _artist = TextEditingController(text: widget.song?.artist ?? '');
    _content = TextEditingController(text: widget.song?.content ?? '');
    _originalKey = TextEditingController(text: widget.song?.originalKey ?? '');
    _audioUrl = TextEditingController(text: widget.song?.audioUrl ?? '');
    _audioDuration = TextEditingController(
      text: widget.song?.audioDurationSeconds != null
          ? Song.formatDuration(widget.song!.audioDurationSeconds)
          : '',
    );
    _titleFocusNode = FocusNode();
    _artistFocusNode = FocusNode();
    _keyFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
    _audioFocusNode = FocusNode();
    _isFavorite = widget.song?.isFavorite ?? false;
    _tags = widget.song?.tags.toList() ?? [];
    _imageUrl = widget.song?.imageUrl;
    _lastValidSelection = TextSelection.collapsed(offset: _content.text.length);
    _content.addListener(_preserveContentSelection);

    if (_originalKey.text.isEmpty && _content.text.isNotEmpty) {
      final detected = ChordTransposer.detectKey(_content.text);
      if (detected != null && detected.isNotEmpty) {
        _originalKey.text = detected;
      }
    }
  }

  void _preserveContentSelection() {
    final sel = _content.selection;
    if (sel.isValid && sel.start >= 0 && sel.end >= 0) {
      _lastValidSelection = sel;
    }
  }

  @override
  void dispose() {
    _content.removeListener(_preserveContentSelection);
    _categoryBarScrollController.dispose();
    _chordBarScrollController.dispose();
    _minorChordBarScrollController.dispose();
    _title.dispose();
    _artist.dispose();
    _content.dispose();
    _originalKey.dispose();
    _audioUrl.dispose();
    _audioDuration.dispose();
    _titleFocusNode.dispose();
    _artistFocusNode.dispose();
    _keyFocusNode.dispose();
    _contentFocusNode.dispose();
    _audioFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteAudioUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      final clean = Song.cleanAudioUrl(text);
      setState(() {
        _audioUrl.text = clean ?? '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link colado com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum link copiado na área de transferência.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _setQuickDuration(String dur) {
    setState(() {
      _audioDuration.text = dur;
    });
  }

  void _scrollToAudio() {
    _audioFocusNode.requestFocus();
    if (_audioKey.currentContext != null) {
      Scrollable.ensureVisible(
        _audioKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuração de Áudio & Karaokê abaixo.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _pickMp3File() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      );
      if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
        final path = res.files.single.path!;
        final name = res.files.single.name;
        setState(() {
          _audioUrl.text = path;
          if (_audioDuration.text.trim().isEmpty) {
            _audioDuration.text = '03:30';
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Arquivo "$name" selecionado! Ajuste a duração se necessário.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao escolher arquivo: $e')),
        );
      }
    }
  }

  Future<void> _pickSongImageFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'gif', 'jpg', 'jpeg'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final file = res.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) return;

      final ext = (file.extension ?? 'png').toLowerCase();
      String mime = 'image/png';
      if (ext == 'gif') {
        mime = 'image/gif';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        mime = 'image/jpeg';
      }
      final b64 = base64Encode(bytes);
      setState(() {
        _imageUrl = 'data:$mime;base64,$b64';
        _imageFileName = file.name;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagem "${file.name}" carregada para a cifra!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar imagem: $e')),
        );
      }
    }
  }

  void _insertSectionTag(String tag) {
    final text = _content.text;
    final currentSel = _content.selection;
    final activeSel = (currentSel.isValid && currentSel.start >= 0 && currentSel.end >= 0)
        ? currentSel
        : _lastValidSelection;
    final insertText = text.isEmpty ? '$tag\n' : '\n$tag\n';

    if (activeSel.isValid && activeSel.start >= 0 && activeSel.end >= 0) {
      final start = activeSel.start.clamp(0, text.length);
      final end = activeSel.end.clamp(start, text.length);
      final newText = text.replaceRange(start, end, insertText);
      final newSelection = TextSelection.collapsed(offset: start + insertText.length);
      _lastValidSelection = newSelection;
      _content.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
    } else {
      final newText = text.isEmpty ? '$tag\n' : '$text$insertText';
      final newSelection = TextSelection.collapsed(offset: newText.length);
      _lastValidSelection = newSelection;
      _content.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
    }
    _contentFocusNode.requestFocus();
  }

  void _insertChord(String chord) {
    final text = _content.text;
    final currentSel = _content.selection;
    final activeSel = (currentSel.isValid && currentSel.start >= 0 && currentSel.end >= 0)
        ? currentSel
        : _lastValidSelection;
    final toInsert = '$chord ';

    if (activeSel.isValid && activeSel.start >= 0 && activeSel.end >= 0) {
      final start = activeSel.start.clamp(0, text.length);
      final end = activeSel.end.clamp(start, text.length);
      final newText = text.replaceRange(start, end, toInsert);
      final newSelection = TextSelection.collapsed(offset: start + toInsert.length);
      _lastValidSelection = newSelection;
      _content.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
    } else {
      final newText = text.isEmpty ? toInsert : '$text $toInsert';
      final newSelection = TextSelection.collapsed(offset: newText.length);
      _lastValidSelection = newSelection;
      _content.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
    }
    _contentFocusNode.requestFocus();
  }

  void _detectKey() {
    final detected = ChordTransposer.detectKey(_content.text);
    if (detected != null && detected.isNotEmpty) {
      setState(() => _originalKey.text = detected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tom detectado nos acordes: $detected'),
          backgroundColor: const Color(0xFF6366F1),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar o tom automaticamente.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _importLink() async {
    final song = await ImportLinkDialog.show(context);
    if (song != null) {
      setState(() {
        _title.text = song.title;
        _artist.text = song.artist;
        _content.text = song.content;
        if (song.originalKey.isNotEmpty) {
          _originalKey.text = song.originalKey;
        } else {
          final det = ChordTransposer.detectKey(song.content);
          if (det != null) _originalKey.text = det;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cifra "${song.title}" carregada com sucesso!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'zip'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    if (result.files.length == 1 && result.files.first.extension?.toLowerCase() == 'txt') {
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) return;

      final text = utf8.decode(bytes, allowMalformed: true);
      final meta = CifraImportService.extractMetadata(content: text, rawFileName: file.name);

      setState(() {
        _content.text = text;
        if (_title.text.trim().isEmpty || _title.text.trim() == 'Sem título') {
          _title.text = meta.title;
        }
        if (_artist.text.trim().isEmpty && meta.artist.isNotEmpty) {
          _artist.text = meta.artist;
        }
        if (_originalKey.text.trim().isEmpty && meta.originalKey.isNotEmpty) {
          _originalKey.text = meta.originalKey;
        }
      });
      return;
    }

    final songs = <Song>[];
    for (final file in result.files) {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) continue;

      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'zip') {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final item in archive) {
          if (!item.isFile) continue;
          if (item.name.toLowerCase().endsWith('.txt') && !item.name.startsWith('__MACOSX/')) {
            final text = utf8.decode(item.content as List<int>, allowMalformed: true);
            songs.add(CifraImportService.songFromContentAndFileName(
              content: text,
              rawFileName: item.name,
            ));
          }
        }
      } else if (ext == 'txt') {
        final text = utf8.decode(bytes, allowMalformed: true);
        songs.add(CifraImportService.songFromContentAndFileName(
          content: text,
          rawFileName: file.name,
        ));
      }
    }

    if (songs.isEmpty) return;

    await widget.repository.saveAll(songs);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Importação Concluída'),
          ],
        ),
        content: Text(
          '${songs.length} cifra(s) foram incluídas com sucesso na sua biblioteca!',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o título da música.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final key = _originalKey.text.trim();
    final audio = Song.cleanAudioUrl(_audioUrl.text.trim());
    final hasValidAudio = audio != null && audio.isNotEmpty;
    final durationSeconds = hasValidAudio ? Song.parseDuration(_audioDuration.text) : null;
    final cleanImg = _imageUrl?.trim();
    final hasValidImage = cleanImg != null && cleanImg.isNotEmpty;
    final old = widget.song;
    final song = old == null
        ? Song(
            id: const Uuid().v4(),
            title: title,
            artist: _artist.text.trim(),
            content: _content.text,
            originalKey: key.isNotEmpty ? key : (ChordTransposer.detectKey(_content.text) ?? ''),
            isFavorite: _isFavorite,
            tags: _tags,
            audioUrl: hasValidAudio ? audio : null,
            audioDurationSeconds: durationSeconds,
            imageUrl: hasValidImage ? cleanImg : null,
          )
        : old.copyWith(
            title: title,
            artist: _artist.text.trim(),
            content: _content.text,
            originalKey: key.isNotEmpty ? key : old.originalKey,
            isFavorite: _isFavorite,
            tags: _tags,
            audioUrl: hasValidAudio ? audio : null,
            audioDurationSeconds: durationSeconds,
            imageUrl: hasValidImage ? cleanImg : null,
          );

    await widget.repository.save(song);
    if (!mounted) return;

    final savedInRepo = widget.repository.allSongs
        .where((s) => s.id == song.id)
        .firstOrNull ?? song;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cifra "$title" salva com sucesso!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
    Navigator.pop(context, savedInRepo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactScreen = screenWidth < 600;

    final cardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.92);
    final editorBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.88)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? AppCores.roxo.withValues(alpha: 0.22)
        : AppCores.roxo.withValues(alpha: 0.14);
    final inputFill = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.7)
        : const Color(0xFFF1F5F9);

    final lineCount = _content.text.isEmpty ? 0 : _content.text.split('\n').length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: isCompactScreen ? 4 : 0,
        title: Row(
          children: [
            if (screenWidth >= 480) ...[
              BadgeIconeGradiente(
                icon: _isEditing ? Icons.edit_note_rounded : Icons.add_rounded,
                size: 38,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isEditing ? 'Editar Cifra' : 'Nova Cifra',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompactScreen ? 15 : 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (screenWidth > 520)
                    Text(
                      _isEditing
                          ? 'Personalize a letra, acordes e detalhes'
                          : 'Adicione uma nova cifra ao seu repertório',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final isWide = screenWidth > 720;

              // Botão de atalho rápido para a seção de Áudio e Karaokê
              final audioButton = OutlinedButton.icon(
                onPressed: _scrollToAudio,
                icon: Icon(
                  _audioUrl.text.isNotEmpty
                      ? Icons.music_note_rounded
                      : Icons.add_link_rounded,
                  size: 15,
                  color: _audioUrl.text.isNotEmpty
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1),
                ),
                label: Text(
                  _audioUrl.text.isNotEmpty
                      ? 'Áudio Conectado'
                      : 'Áudio / Karaokê',
                  style: TextStyle(
                    fontSize: isCompactScreen ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: _audioUrl.text.isNotEmpty
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _audioUrl.text.isNotEmpty
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1),
                  side: BorderSide(
                    color: (_audioUrl.text.isNotEmpty
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6366F1))
                        .withValues(alpha: 0.4),
                  ),
                  backgroundColor: (_audioUrl.text.isNotEmpty
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6366F1))
                      .withValues(alpha: isDark ? 0.14 : 0.06),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompactScreen ? 8 : 11,
                    vertical: isCompactScreen ? 6 : 8,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );

              // Se ESTÁ EDITANDO, exibe botão de Áudio e Salvar
              if (_isEditing) {
                return Padding(
                  padding: EdgeInsets.only(right: isCompactScreen ? 8 : 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      audioButton,
                      const SizedBox(width: 8),
                      BotaoGradiente(
                        key: const ValueKey('save_song_button'),
                        onPressed: _save,
                        icon: Icons.check_circle_rounded,
                        iconSize: isCompactScreen ? 16 : 18,
                        fontSize: isCompactScreen ? 12.5 : 13.5,
                        padding: isCompactScreen
                            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
                            : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        label: isCompactScreen ? 'Salvar' : 'Salvar Cifra',
                      ),
                    ],
                  ),
                );
              }

              // Se é NOVA CIFRA, oferece botão de Áudio, importação e Salvar
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (screenWidth > 580) ...[
                    audioButton,
                    const SizedBox(width: 8),
                  ],
                  if (isWide) ...[
                    OutlinedButton.icon(
                      onPressed: _importLink,
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Importar por Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppCores.roxo,
                        side: BorderSide(color: AppCores.roxo.withValues(alpha: 0.4)),
                        backgroundColor: AppCores.roxo.withValues(alpha: isDark ? 0.12 : 0.05),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _importFiles,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Importar Arquivos (.txt / .zip)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey[200] : Colors.grey[800],
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.02),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ] else ...[
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.file_download_outlined),
                      padding: isCompactScreen ? EdgeInsets.zero : const EdgeInsets.all(8),
                      constraints: isCompactScreen ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
                      tooltip: 'Opções de importação e áudio',
                      onSelected: (val) {
                        if (val == 'audio') _scrollToAudio();
                        if (val == 'link') _importLink();
                        if (val == 'file') _importFiles();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'audio',
                          child: Row(
                            children: [
                              Icon(Icons.music_note_rounded, size: 18, color: Color(0xFF6366F1)),
                              SizedBox(width: 10),
                              Text('Áudio & Karaokê'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'link',
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 18, color: AppCores.roxo),
                              SizedBox(width: 10),
                              Text('Importar cifra por link'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'file',
                          child: Row(
                            children: [
                              Icon(Icons.upload_file_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Importar arquivos (.txt / .zip)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(width: isCompactScreen ? 4 : 8),
                  BotaoGradiente(
                    key: const ValueKey('save_new_song_button'),
                    onPressed: _save,
                    icon: Icons.check_circle_rounded,
                    iconSize: isCompactScreen ? 16 : 18,
                    fontSize: isCompactScreen ? 12.5 : 13.5,
                    padding: isCompactScreen
                        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    label: isCompactScreen ? 'Salvar' : 'Salvar Cifra',
                  ),
                  SizedBox(width: isCompactScreen ? 8 : 12),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompactScreen ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMetadataCard(cardBg, borderColor, isCompactScreen, inputFill, isDark),
            const SizedBox(height: 10),
            _buildEditorCard(cardBg, borderColor, inputFill, isDark, lineCount, editorBg),
            const SizedBox(height: 70),
          ],
        ),
      ),
      // Barra de Ferramentas Flutuante na parte inferior acima do teclado
      bottomNavigationBar: _showChordBar
          ? _buildFloatingChordBar(isDark, borderColor)
          : null,
    );
  }

  Widget _buildMetadataCard(
    Color cardBg,
    Color borderColor,
    bool isCompactScreen,
    Color inputFill,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isCompactScreen ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // Em telas muito estreitas / mobile (< 500px)
              if (width < 500) {
                return Column(
                  children: [
                    _buildTitleField(inputFill, isDark),
                    const SizedBox(height: 8),
                    _buildArtistField(inputFill, isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildKeyField(inputFill, isDark, compact: width < 360)),
                        const SizedBox(width: 8),
                        _buildFavoriteButton(isDark, compact: width < 360),
                      ],
                    ),
                  ],
                );
              }

              // Em telas médias (< 760px)
              if (width < 760) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTitleField(inputFill, isDark)),
                        const SizedBox(width: 10),
                        _buildFavoriteButton(isDark, compact: false),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildArtistField(inputFill, isDark)),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _buildKeyField(inputFill, isDark, compact: false)),
                      ],
                    ),
                  ],
                );
              }

              // Em telas amplas (desktop)
              return Row(
                children: [
                  Expanded(flex: 5, child: _buildTitleField(inputFill, isDark)),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _buildArtistField(inputFill, isDark)),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildKeyField(inputFill, isDark, compact: false)),
                  const SizedBox(width: 12),
                  _buildFavoriteButton(isDark, compact: false),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 820) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildThemesSection(inputFill, isDark),
                          const SizedBox(height: 10),
                          _buildImageSection(inputFill, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: _buildAudioSection(inputFill, isDark),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildThemesSection(inputFill, isDark),
                  const SizedBox(height: 10),
                  _buildImageSection(inputFill, isDark),
                  const SizedBox(height: 10),
                  _buildAudioSection(inputFill, isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard(
    Color cardBg,
    Color borderColor,
    Color inputFill,
    bool isDark,
    int lineCount,
    Color editorBg,
  ) {
    final textFieldWidget = Container(
      color: editorBg,
      child: TextField(
        key: const ValueKey('edit_song_content_field'),
        controller: _content,
        focusNode: _contentFocusNode,
        maxLines: null,
        minLines: 16,
        onTapOutside: (_) {
          // Mantém o foco e o cursor estáveis ao arrastar ou tocar na barra de acordes no celular
        },
        onChanged: (_) {
          final newCount = _content.text.isEmpty ? 0 : _content.text.split('\n').length;
          if (newCount != lineCount) setState(() {});
        },
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.45,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          hintText:
              'Digite ou cole a letra e acordes da música aqui...\n\nVocê também pode clicar nos acordes da barra flutuante inferior para inseri-los no cursor!\n\nExemplo:\n   C               G\nMinha alma tem sede de Ti\n   Am              F\nEm uma terra seca e sem água',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra Superior do Editor: Tags rápidas, contador de linhas, alternar acordes e limpar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 5),
                    const Text(
                      'Cifra & Letra',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$lineCount lin.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão para exibir/ocultar a barra flutuante de acordes
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _showChordBar = !_showChordBar),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showChordBar
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showChordBar
                                ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showChordBar
                                  ? Icons.keyboard_hide_rounded
                                  : Icons.piano_rounded,
                              size: 14,
                              color: _showChordBar
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showChordBar ? 'Ocultar Acordes' : 'Acordes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _showChordBar
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_content.text.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.clear_all_rounded, size: 17),
                        tooltip: 'Limpar texto',
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Limpar cifra'),
                              content: const Text('Deseja apagar todo o conteúdo digitado?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _content.clear());
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Editor Text Field Area
          textFieldWidget,
        ],
      ),
    );
  }

  /// Barra de Ferramentas Flutuante na parte inferior (acima do teclado)
  /// Protegida com TextFieldTapRegion para não perder o foco, o cursor ou a
  /// funcionalidade ao arrastar para o lado no celular.
  Widget _buildFloatingChordBar(bool isDark, Color borderColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileCompact = screenWidth < 620;

    return TextFieldTapRegion(
      child: Container(
        key: const ValueKey('floating_chord_bar'),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.97),
          border: Border(top: BorderSide(color: borderColor, width: 1.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Linha 1: Seletor de categorias e botão recolher
                Row(
                  children: [
                    const Icon(Icons.piano_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('chord_categories_scroll'),
                        controller: _categoryBarScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: Row(
                          children: [
                            _buildCategoryChip('Naturais', isDark),
                            _buildCategoryChip('Com 7ª', isDark),
                            _buildCategoryChip('Com Baixo', isDark),
                            _buildCategoryChip('Sustenidos / Bemóis', isDark),
                            _buildCategoryChip('Tags', isDark),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.keyboard_hide_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      tooltip: 'Ocultar barra de acordes',
                      onPressed: () => setState(() => _showChordBar = false),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Linha 2: Acordes da categoria selecionada ou Tags
                _buildResponsiveChordRows(isDark, borderColor, isMobileCompact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveChordRows(bool isDark, Color borderColor, bool isMobileCompact) {
    if (!isMobileCompact) {
      return SingleChildScrollView(
        key: const ValueKey('chord_buttons_scroll'),
        controller: _chordBarScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: _selectedChordCategory == 'Tags'
            ? Row(children: _sectionTags.map((t) => _buildTagButton(t, isDark)).toList())
            : _buildChordButtonsRow(isDark, borderColor),
      );
    }

    // No celular (< 620px), organiza os acordes em 2 linhas compactas e roláveis
    // para que todos os acordes fiquem acessíveis sem sumir ao arrastar para o lado
    Widget row1;
    Widget row2;

    switch (_selectedChordCategory) {
      case 'Com 7ª':
        final firstHalf = _sevenths.sublist(0, 7);
        final secondHalf = _sevenths.sublist(7);
        row1 = Row(
          children: firstHalf
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: !c.contains('m')))
              .toList(),
        );
        row2 = Row(
          children: secondHalf
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: !c.contains('m')))
              .toList(),
        );
        break;
      case 'Com Baixo':
        final firstHalf = _slashChords.sublist(0, 5);
        final secondHalf = _slashChords.sublist(5);
        row1 = Row(
          children: firstHalf
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: true))
              .toList(),
        );
        row2 = Row(
          children: secondHalf
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: true))
              .toList(),
        );
        break;
      case 'Sustenidos / Bemóis':
        final firstHalf = _accidentals.sublist(0, 5);
        final secondHalf = _accidentals.sublist(5);
        row1 = Row(
          children: firstHalf
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: !c.contains('m')))
              .toList(),
        );
        row2 = Row(
          children: secondHalf
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: !c.contains('m')))
              .toList(),
        );
        break;
      case 'Tags':
        final firstHalf = _sectionTags.sublist(0, 4);
        final secondHalf = _sectionTags.sublist(4);
        row1 = Row(children: firstHalf.map((t) => _buildTagButton(t, isDark)).toList());
        row2 = Row(children: secondHalf.map((t) => _buildTagButton(t, isDark)).toList());
        break;
      case 'Naturais':
      default:
        row1 = Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Maiores',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
            const SizedBox(width: 5),
            ..._majorNaturals.map((c) => _buildChordButton(c, isDark: isDark, isMajor: true)),
          ],
        );
        row2 = Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7E22CE).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Menores',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E22CE),
                ),
              ),
            ),
            const SizedBox(width: 5),
            ..._minorNaturals.map((c) => _buildChordButton(c, isDark: isDark, isMajor: false)),
          ],
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          key: const ValueKey('chord_buttons_scroll'),
          controller: _chordBarScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: row1,
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          key: const ValueKey('chord_buttons_minor_scroll'),
          controller: _minorChordBarScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: row2,
        ),
      ],
    );
  }

  Widget _buildTagButton(String tag, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(6),
        onTap: () => _insertSectionTag(tag),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF334155).withValues(alpha: 0.5)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioSection(Color fill, bool isDark) {
    final url = _audioUrl.text.trim();
    final lower = url.toLowerCase();

    Color serviceColor = const Color(0xFF6366F1);
    IconData serviceIcon = Icons.audio_file_rounded;
    String serviceName = 'Arquivo MP3 / Áudio';

    if (lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        Song.extractYoutubeVideoId(url) != null) {
      serviceColor = const Color(0xFFEF4444);
      serviceIcon = Icons.play_circle_fill_rounded;
      serviceName = 'YouTube';
    }

    final accentBg = url.isNotEmpty
        ? serviceColor.withValues(alpha: isDark ? 0.15 : 0.08)
        : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC));
    final borderAccent = url.isNotEmpty
        ? serviceColor.withValues(alpha: 0.45)
        : (isDark ? Colors.white24 : const Color(0xFFE2E8F0));

    return Container(
      key: _audioKey,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderAccent, width: url.isNotEmpty ? 1.5 : 1.0),
        boxShadow: url.isNotEmpty
            ? [
                BoxShadow(
                  color: serviceColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho destacado: Ícone, Título, Badge do Serviço e Botões de Ação
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(serviceIcon, size: 16, color: serviceColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Áudio & Karaokê',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (url.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: serviceColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    serviceName,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Sincroniza a rolagem com a música',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Botões Rápidos de Ação: Colar Link, Remover Link e Carregar MP3
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pasteAudioUrl,
                    icon: const Icon(Icons.content_paste_rounded, size: 13),
                    label: const Text('Colar Link', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                      foregroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (url.isNotEmpty)
                    OutlinedButton.icon(
                      key: const ValueKey('remove_audio_link_btn'),
                      onPressed: () {
                        setState(() {
                          _audioUrl.clear();
                          _audioDuration.clear();
                        });
                      },
                      icon: const Icon(Icons.link_off_rounded, size: 13),
                      label: const Text('Remover Link', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _pickMp3File,
                    icon: const Icon(Icons.folder_open_rounded, size: 13),
                    label: const Text('Carregar MP3', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Campo Principal: URL ou Arquivo de Áudio
          TextField(
            key: const ValueKey('edit_song_audio_url_field'),
            controller: _audioUrl,
            focusNode: _audioFocusNode,
            style: const TextStyle(fontSize: 12.5),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Áudio da Música (Link do YouTube ou Arquivo MP3)',
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              hintText: 'Cole o link do YouTube (ex: youtube.com/watch?v=...) ou escolha um MP3',
              hintStyle: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              prefixIcon: Icon(serviceIcon, size: 17, color: serviceColor),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_audioUrl.text.isNotEmpty)
                    IconButton(
                      key: const ValueKey('clear_audio_url_btn'),
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        setState(() {
                          _audioUrl.clear();
                          _audioDuration.clear();
                        });
                      },
                      tooltip: 'Limpar link',
                    ),
                  IconButton(
                    icon: const Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF6366F1)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _pickMp3File,
                    tooltip: 'Escolher arquivo MP3',
                  ),
                ],
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                  : Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: url.isNotEmpty
                      ? serviceColor.withValues(alpha: 0.4)
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: serviceColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Campo de Duração e Chips de Atalho Rápido
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _audioDuration,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Duração (mm:ss)',
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    hintText: '03:30',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    prefixIcon: const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF6366F1)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Atalhos:',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    for (final dur in ['02:30', '03:00', '03:30', '04:00', '04:30', '05:00'])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _setQuickDuration(dur),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _audioDuration.text.trim() == dur
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _audioDuration.text.trim() == dur
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? Colors.white12 : Colors.black12),
                              ),
                            ),
                            child: Text(
                              dur,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: _audioDuration.text.trim() == dur
                                    ? Colors.white
                                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isDark) {
    final isSelected = _selectedChordCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _selectedChordCategory = category);
          if (_chordBarScrollController.hasClients) {
            _chordBarScrollController.jumpTo(0);
          }
          if (_minorChordBarScrollController.hasClients) {
            _minorChordBarScrollController.jumpTo(0);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChordButtonsRow(bool isDark, Color borderColor) {
    switch (_selectedChordCategory) {
      case 'Com 7ª':
        return Row(
          children: _sevenths
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: !c.contains('m')))
              .toList(),
        );
      case 'Com Baixo':
        return Row(
          children: _slashChords
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: true))
              .toList(),
        );
      case 'Sustenidos / Bemóis':
        return Row(
          children: _accidentals
              .map((c) => _buildChordButton(c, isDark: isDark, isMajor: !c.contains('m')))
              .toList(),
        );
      case 'Naturais':
      default:
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Maiores',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(width: 5),
            ..._majorNaturals.map((c) => _buildChordButton(c, isDark: isDark, isMajor: true)),
            const SizedBox(width: 8),
            Container(width: 1, height: 16, color: borderColor),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7E22CE).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Menores',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
              ),
            ),
            const SizedBox(width: 5),
            ..._minorNaturals.map((c) => _buildChordButton(c, isDark: isDark, isMajor: false)),
          ],
        );
    }
  }

  Widget _buildChordButton(
    String chord, {
    required bool isDark,
    required bool isMajor,
  }) {
    final bg = isMajor
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
        : (isDark ? const Color(0xFF28233C) : const Color(0xFFF3E8FF));
    final textColor = isMajor
        ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA))
        : (isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE));
    final border = isMajor
        ? (isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE))
        : (isDark ? const Color(0xFF581C87) : const Color(0xFFE9D5FF));

    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        key: ValueKey('chord_chip_$chord'),
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(6),
        onTap: () => _insertChord(chord),
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(
            chord,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(Color fill, bool isDark) {
    return TextField(
      key: const ValueKey('edit_song_title_field'),
      controller: _title,
      focusNode: _titleFocusNode,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Título da Música *',
        labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
        hintText: 'Ex: Te Farei Vencer',
        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: const Icon(Icons.music_note_rounded, size: 18, color: Color(0xFF6366F1)),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildArtistField(Color fill, bool isDark) {
    return TextField(
      key: const ValueKey('edit_song_artist_field'),
      controller: _artist,
      focusNode: _artistFocusNode,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: 'Artista / Cantor(a)',
        labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
        hintText: 'Ex: Adriana Arydes',
        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF6366F1)),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildKeyField(Color fill, bool isDark, {bool compact = false}) {
    return TextField(
      key: const ValueKey('edit_song_key_field'),
      controller: _originalKey,
      focusNode: _keyFocusNode,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: compact ? 'Tom' : 'Tom Original',
        labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
        hintText: 'C#m',
        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: const Icon(Icons.piano_rounded, size: 16, color: Color(0xFF6366F1)),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        suffixIcon: IconButton(
          icon: const Icon(Icons.auto_fix_high_rounded, size: 15, color: Color(0xFF6366F1)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Detectar tom da cifra',
          onPressed: _detectKey,
        ),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(bool isDark, {bool compact = false}) {
    return Tooltip(
      message: _isFavorite ? 'Música favorita' : 'Marcar como favorita',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _isFavorite = !_isFavorite),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 10,
            vertical: compact ? 9 : 9,
          ),
          decoration: BoxDecoration(
            color: _isFavorite
                ? Colors.amber.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFavorite
                  ? Colors.amber.shade400
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite ? Colors.amber[700] : Colors.grey[500],
                size: 20,
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  'Favorita',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _isFavorite ? FontWeight.bold : FontWeight.normal,
                    color: _isFavorite
                        ? (isDark ? Colors.amber[300] : Colors.amber[900])
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemesSection(Color inputFill, bool isDark) {
    final availableThemes = widget.musicThemes?.themes ?? const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: isDark ? 0.25 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined, size: 16, color: Color(0xFF6366F1)),
                  SizedBox(width: 6),
                  Text(
                    'Temas / Estilos:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showManageThemesDialog(availableThemes),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        _tags.isEmpty ? 'Adicionar Tema' : 'Gerenciar Temas',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nenhum tema definido (ex: Adoração, Louvor, Baião, Casamento...)',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 13, color: Color(0xFF6366F1)),
                    onDeleted: () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewThumb(String imageUrl) {
    Widget fallback() {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppCores.gradienteLogo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
      );
    }

    if (imageUrl.startsWith('data:image')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final b64 = commaIdx >= 0 ? imageUrl.substring(commaIdx + 1) : imageUrl;
        final bytes = base64Decode(b64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      } catch (_) {
        return fallback();
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  Widget _buildImageSection(Color inputFill, bool isDark) {
    final hasImage = _imageUrl != null && _imageUrl!.trim().isNotEmpty;

    return Container(
      key: const ValueKey('edit_song_image_section'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasImage
              ? AppCores.roxo.withValues(alpha: 0.45)
              : Colors.grey.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
      ),
      child: Row(
        children: [
          if (hasImage)
            _buildImagePreviewThumb(_imageUrl!.trim())
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppCores.roxo.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_outlined,
                color: AppCores.roxo,
                size: 20,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Imagem da Cifra (Comunidade)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasImage
                      ? (_imageFileName ?? 'Imagem anexada para exibição na comunidade')
                      : 'Opcional: envie PNG, GIF ou JPG para exibir na comunidade',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: hasImage
                        ? Colors.green
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    fontWeight: hasImage ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (hasImage)
            IconButton(
              key: const ValueKey('btn_remove_song_image'),
              tooltip: 'Remover imagem',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
              onPressed: () {
                setState(() {
                  _imageUrl = null;
                  _imageFileName = null;
                });
              },
            ),
          OutlinedButton.icon(
            key: const ValueKey('btn_upload_song_image'),
            onPressed: _pickSongImageFile,
            icon: const Icon(Icons.upload_file_rounded, size: 15),
            label: Text(
              hasImage ? 'Trocar' : 'Enviar Imagem',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppCores.roxo,
              side: BorderSide(color: AppCores.roxo.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageThemesDialog(List<String> availableThemes) {
    final searchCtrl = TextEditingController();
    final newThemeCtrl = TextEditingController();
    final tempSelected = Set<String>.from(_tags);
    final allThemesList = List<String>.from(availableThemes);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final query = searchCtrl.text.trim().toLowerCase();
          final filteredThemes = allThemesList
              .where((t) => query.isEmpty || t.toLowerCase().contains(query))
              .toList();

          return CartaoDialogoModerno(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BadgeIconeGradiente(
                      icon: Icons.folder_special_rounded,
                      size: 42,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temas e Estilos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Selecione os temas ou cadastre um novo estilo',
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
                const SizedBox(height: 16),
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar tema...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppCores.roxo),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredThemes.map((theme) {
                        final isChecked = tempSelected.contains(theme);
                        return FilterChip(
                          selected: isChecked,
                          selectedColor: AppCores.roxo.withValues(alpha: 0.2),
                          checkmarkColor: AppCores.roxo,
                          label: Text(
                            theme,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                              color: isChecked
                                  ? (isDark ? Colors.purple[200] : AppCores.roxo)
                                  : null,
                            ),
                          ),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                tempSelected.add(theme);
                              } else {
                                tempSelected.remove(theme);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newThemeCtrl,
                        decoration: InputDecoration(
                          hintText: 'Novo tema (ex: Baião, Louvor)...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BotaoGradiente(
                      onPressed: () async {
                        final name = newThemeCtrl.text.trim();
                        if (name.isNotEmpty) {
                          if (widget.musicThemes != null) {
                            await widget.musicThemes!.addTheme(name);
                          }
                          setDialogState(() {
                            tempSelected.add(name);
                            if (!allThemesList.contains(name)) {
                              allThemesList.add(name);
                              allThemesList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                            }
                            newThemeCtrl.clear();
                          });
                        }
                      },
                      label: 'Criar',
                      icon: Icons.add_rounded,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
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
                    BotaoGradiente(
                      onPressed: () {
                        setState(() {
                          _tags = tempSelected.toList();
                        });
                        Navigator.pop(ctx);
                      },
                      label: 'Concluir',
                      icon: Icons.check_rounded,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
}
