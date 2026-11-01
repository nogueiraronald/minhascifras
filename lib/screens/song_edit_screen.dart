import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/song_repository.dart';
import '../models/song.dart';

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

  Future<void> _importTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      _content.text = utf8.decode(bytes, allowMalformed: true);
      if (_title.text.trim().isEmpty) {
        _title.text = file.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
      }
    });
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
              tooltip: 'Importar .txt',
              icon: const Icon(Icons.upload_file),
              onPressed: _importTxt),
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
