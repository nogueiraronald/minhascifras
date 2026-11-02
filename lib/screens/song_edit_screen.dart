import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/song_repository.dart';
import '../models/song.dart';
import '../widgets/import_link_dialog.dart';

class SongEditScreen extends StatefulWidget {
  const SongEditScreen({super.key, required this.repository, this.song});

  final SongRepository repository;
  final Song? song;

  @override
  State<SongEditScreen> createState() => _SongEditScreenState();
}

class _SongEditScreenState extends State<SongEditScreen> {
  late final _title = TextEditingController(text: widget.song?.title ?? '');
  late final _artist = TextEditingController(text: widget.song?.artist ?? '');
  late final _content = TextEditingController(text: widget.song?.content ?? '');

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _importLink() async {
    final song = await ImportLinkDialog.show(context);
    if (song != null) {
      setState(() {
        _title.text = song.title;
        _artist.text = song.artist;
        _content.text = song.content;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cifra "${song.title}" carregada no formulário.')),
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

      setState(() {
        _content.text = utf8.decode(bytes!, allowMalformed: true);
        if (_title.text.trim().isEmpty) {
          _title.text = file.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
        }
      });
      return;
    }

    // Se selecionou múltiplos arquivos ou um arquivo .zip
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
            songs.add(_createSongFromFileName(item.name, text));
          }
        }
      } else if (ext == 'txt') {
        final text = utf8.decode(bytes, allowMalformed: true);
        songs.add(_createSongFromFileName(file.name, text));
      }
    }

    if (songs.isEmpty) return;

    await widget.repository.saveAll(songs);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${songs.length} cifra(s) importada(s) para a biblioteca!')),
    );
    Navigator.pop(context);
  }

  Song _createSongFromFileName(String rawName, String content) {
    var name = rawName.split('/').last.split(r'\').last;
    name = name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '').trim();
    name = name.replaceAll(RegExp(r'^\d+\s*-\s*'), '');

    String artist = '';
    String title = name;
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    }
    return Song(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Sem título' : title,
      artist: artist,
      content: content,
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o título.')));
      return;
    }
    final old = widget.song;
    final song = old == null
        ? Song(
            id: const Uuid().v4(),
            title: title,
            artist: _artist.text.trim(),
            content: _content.text)
        : old.copyWith(title: title, artist: _artist.text.trim(), content: _content.text);
    await widget.repository.save(song);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song == null ? 'Nova cifra' : 'Editar cifra'),
        actions: [
          IconButton(
            tooltip: 'Importar por link',
            icon: const Icon(Icons.link),
            onPressed: _importLink,
          ),
          IconButton(
            tooltip: 'Importar arquivo(s) .txt / .zip',
            icon: const Icon(Icons.upload_file),
            onPressed: _importFiles,
          ),
          IconButton(tooltip: 'Salvar', icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: _artist, decoration: const InputDecoration(labelText: 'Artista')),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _content,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                    labelText: 'Cifra (acordes sobre a letra)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
