import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../dados/controlador_conta.dart';
import 'estilo_app.dart';

/// Diálogo moderno de Sincronização em Nuvem com QR Code e pareamento sem login/senha.
/// Totalmente responsivo para celulares (iOS/Android) e navegadores desktop.
class DesktopLoginDialog extends StatefulWidget {
  const DesktopLoginDialog({super.key, required this.account});

  final AccountController account;

  static Future<void> show(BuildContext context, AccountController account) {
    return showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => DesktopLoginDialog(account: account),
    );
  }

  @override
  State<DesktopLoginDialog> createState() => _DesktopLoginDialogState();
}

class _DesktopLoginDialogState extends State<DesktopLoginDialog> {
  final _codeCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _error;
  bool _showCodeText = false;
  bool _showManualInput = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteCode() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        final code = AccountController.extractCode(text);
        setState(() {
          _codeCtrl.text = code;
          _error = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Código "$code" colado com sucesso!'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppCores.roxo,
            ),
          );
        }
      } else {
        setState(() => _error = 'A área de transferência está vazia.');
      }
    } catch (_) {
      setState(() {
        _error =
            'Não foi possível ler a área de transferência. Toque no campo e cole.';
      });
    }
  }

  Future<void> _connectToCode() async {
    final code = AccountController.extractCode(_codeCtrl.text);
    if (code.isEmpty) {
      setState(() => _error = 'Por favor, digite ou cole um código válido.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.account.connectToSyncCode(code);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conectado ao repertório $code com sucesso!'),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
      });
    }
  }

  Future<void> _generateNewCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerar Nova Chave?'),
        content: const Text(
          'Isso criará uma nova chave para este aparelho. As cifras locais serão mantidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gerar Nova'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    await widget.account.generateNewSyncCode();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCode = widget.account.syncCode ?? '---';
    final syncUrl = widget.account.syncUrl;

    final mediaQuery = MediaQuery.of(context);
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = viewInsetsBottom > 20;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isSmallScreen = screenWidth < 460;

    // Altura máxima segura para o diálogo acima do teclado virtual
    final maxDialogHeight = math.max(
      220.0,
      screenHeight -
          viewInsetsBottom -
          mediaQuery.padding.top -
          mediaQuery.padding.bottom -
          (isKeyboardOpen ? 24.0 : 64.0),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 24,
        vertical: isKeyboardOpen ? 6 : 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
        ),
        child: CartaoDialogoModerno(
          width: 440,
          margin: EdgeInsets.zero,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: _showManualInput
                ? _buildManualInputView(context, isDark)
                : _buildQrCodeView(
                    context, isDark, currentCode, syncUrl, isSmallScreen),
          ),
        ),
      ),
    );
  }

  /// Visão 1 (Padrão): QR Code de alta visibilidade e Chave Oculta por padrão
  Widget _buildQrCodeView(
    BuildContext context,
    bool isDark,
    String currentCode,
    String syncUrl,
    bool isSmallScreen,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho com ícone e botão fechar
        Row(
          children: [
            const BadgeIconeGradiente(
              icon: Icons.qr_code_2_rounded,
              size: 42,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sincronização em Nuvem',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pareie aparelhos sem cadastro ou senha',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // QR CODE em destaque com fundo branco e contraste nítido
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppCores.roxo.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: syncUrl,
              version: QrVersions.auto,
              size: isSmallScreen ? 155.0 : 175.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1E1B4B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1E1B4B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Instrução amigável
        Text(
          'Aponte a câmera do celular ou tablet para este QR Code para abrir e conectar o mesmo repertório instantaneamente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),

        const SizedBox(height: 10),

        // Botão para ver a chave em texto (Oculta por padrão conforme solicitado)
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _showCodeText = !_showCodeText),
            icon: Icon(
              _showCodeText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 16,
              color: AppCores.roxo,
            ),
            label: Text(
              _showCodeText
                  ? 'Ocultar chave em texto'
                  : 'Ver chave deste aparelho em texto',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppCores.roxo,
              ),
            ),
          ),
        ),

        if (_showCodeText) ...[
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppCores.roxo.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppCores.roxo.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    currentCode,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: AppCores.roxo,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar código',
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: AppCores.roxo),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: currentCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Código "$currentCode" copiado!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 4),

        // Opção secundária: Digitar código caso o usuário não possa escanear
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _showManualInput = true;
                _error = null;
              });
            },
            icon: const Icon(Icons.keyboard_outlined, size: 18),
            label: const Text(
              'Não pode usar a câmera? Digitar chave',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: _generateNewCode,
              child: Text(
                'Nova chave',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            const Spacer(),
            BotaoGradiente(
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              fontSize: 12.5,
              label: 'Concluído',
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ],
    );
  }

  /// Visão 2: Digitação Manual compacta sem o QR Code para caber perfeitamente acima do teclado
  Widget _buildManualInputView(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho com botão Voltar ao QR Code
        Row(
          children: [
            IconButton(
              tooltip: 'Voltar ao QR Code',
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              onPressed: () => setState(() {
                _showManualInput = false;
                _error = null;
              }),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conectar com Outro Aparelho',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Digite ou cole a chave do aparelho principal',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Text(
          'Cole ou digite a chave (Ex: MC-XXXXXX) do aparelho que contém seu repertório:',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),

        // Campo de texto amplo e com estilo mono para a chave
        TextField(
          controller: _codeCtrl,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'Ex: MC-NZKD9A',
            hintStyle: TextStyle(
              letterSpacing: 1,
              fontFamily: 'monospace',
              fontSize: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
            suffixIcon: _codeCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => setState(() => _codeCtrl.clear()),
                  )
                : null,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppCores.roxo, width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _connectToCode(),
        ),

        const SizedBox(height: 12),

        // Botões de Ação: "Colar Chave Copiada" com 1 toque + "Conectar"
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: AppCores.roxo.withValues(alpha: 0.6),
                    width: 1.4,
                  ),
                ),
                onPressed: _pasteCode,
                icon: const Icon(Icons.paste_rounded,
                    size: 16, color: AppCores.roxo),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Colar Chave',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppCores.roxo,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BotaoGradiente(
              onPressed: _loading ? null : _connectToCode,
              isLoading: _loading,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              fontSize: 12.5,
              label: 'Conectar',
              icon: Icons.link_rounded,
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _showManualInput = false;
              _error = null;
            }),
            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
            label: const Text(
              '← Voltar para o QR Code',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
