import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelos/musica.dart';
import '../servicos/servico_importacao_cifra.dart';
import 'estilo_app.dart';

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
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty) {
        setState(() {
          _controller.text = text;
          _error = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link colado com sucesso!'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    // Fallback: se o navegador/Safari bloquear a leitura programática, foca no campo
    _focusNode.requestFocus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toque no campo e selecione "Colar"'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _import() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Por favor, informe ou cole o link da cifra.');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CartaoDialogoModerno(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BadgeIconeGradiente(icon: Icons.link_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Importar Cifra da Internet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Carregue a letra, os acordes e o tom original automaticamente a partir de um link da web.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: AppCores.gradienteTranslucido(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppCores.roxo.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppCores.roxo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cole o link completo da página da cifra para carregar os acordes e o tom.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_loading,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Link da Cifra',
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                hintText: 'https://...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppCores.roxo.withValues(alpha: 0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppCores.roxo.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppCores.roxo,
                    width: 2,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.language_rounded,
                    size: 20, color: AppCores.roxo),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty && !_loading)
                      IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _error = null;
                        }),
                      ),
                    IconButton(
                      tooltip: 'Colar da área de transferência',
                      icon: const Icon(Icons.content_paste_rounded,
                          size: 18, color: AppCores.roxo),
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
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppCores.roxo),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Buscando e processando a cifra da internet...',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppCores.roxo),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              BotaoGradiente(
                onPressed: _loading ? null : _import,
                icon: Icons.cloud_download_rounded,
                label: 'Importar Cifra',
                isLoading: _loading,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
