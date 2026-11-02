import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../services/cifra_import_service.dart';

class ImportLinkDialog extends StatefulWidget {
  const ImportLinkDialog({super.key});

  static Future<Song?> show(BuildContext context) {
    return showDialog<Song>(
      context: context,
      builder: (_) => const ImportLinkDialog(),
    );
  }

  @override
  State<ImportLinkDialog> createState() => _ImportLinkDialogState();
}

class _ImportLinkDialogState extends State<ImportLinkDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _controller.text = text;
        _error = null;
      });
    }
  }

  Future<void> _import() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Informe o link da cifra.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final song = await CifraImportService.importFromUrl(url);
      if (!mounted) return;
      Navigator.pop(context, song);
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.link, color: Colors.blue),
          SizedBox(width: 8),
          Text('Importar por link'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cole o link da página da cifra (ex: Cifra Club):',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_loading,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://www.cifraclub.com.br/...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.music_note_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty && !_loading)
                      IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _error = null;
                        }),
                      ),
                    IconButton(
                      tooltip: 'Colar da área de transferência',
                      icon: const Icon(Icons.content_paste, size: 20),
                      onPressed: _loading ? null : _pasteFromClipboard,
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => _loading ? null : _import(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Buscando e processando cifra...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _import,
          icon: const Icon(Icons.download),
          label: const Text('Importar'),
        ),
      ],
    );
  }
}
