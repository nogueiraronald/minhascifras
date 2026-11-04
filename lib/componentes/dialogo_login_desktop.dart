import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../servicos/recarregador_pagina.dart';

import '../dados/controlador_conta.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../servicos/servico_pdf_recuperacao.dart';
import '../servicos/servico_sincronizacao.dart';
import 'dialogo_desbloqueio_conta.dart';
import 'estilo_app.dart';

/// Diálogo moderno de Sincronização em Nuvem com QR Code, proteção por senha opcional,
/// download de cartão de recuperação em PDF e opção de sair/começar do zero.
class DesktopLoginDialog extends StatefulWidget {
  const DesktopLoginDialog({
    super.key,
    required this.account,
    this.songs,
    this.setlists,
    this.sync,
  });

  final AccountController account;
  final SongRepository? songs;
  final SetlistRepository? setlists;
  final SyncService? sync;

  static Future<void> show(
    BuildContext context,
    AccountController account, {
    SongRepository? songs,
    SetlistRepository? setlists,
    SyncService? sync,
  }) {
    return showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => DesktopLoginDialog(
        account: account,
        songs: songs,
        setlists: setlists,
        sync: sync,
      ),
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
      // 1. Verifica se o repertório na nuvem exige senha
      final remoteHash = await widget.account.checkRemotePassword(code);
      String? verifiedPasswordHash;

      if (remoteHash != null && remoteHash.isNotEmpty) {
        setState(() => _loading = false);
        if (!mounted) return;

        final typedPassword = await _promptPasswordDialog(context, code);
        if (typedPassword == null) return; // Cancelou

        final typedHash =
            sha256.convert(utf8.encode(typedPassword.trim())).toString();
        if (typedHash != remoteHash) {
          setState(() {
            _error =
                'Senha incorreta! Não foi possível autorizar o acesso a este repertório.';
          });
          return;
        }
        verifiedPasswordHash = typedHash;
        setState(() => _loading = true);
      }

      await widget.account.connectToSyncCode(code,
          passwordHash: verifiedPasswordHash);
      await widget.sync?.sync();

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

  Future<String?> _promptPasswordDialog(
      BuildContext context, String code) async {
    final passCtrl = TextEditingController();
    bool obscure = true;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppCores.roxo, size: 22),
              SizedBox(width: 10),
              Text('Repertório Protegido', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A chave $code possui uma senha de proteção configurada.',
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Digite a senha do repertório',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, passCtrl.text),
              child: const Text('Desbloquear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetPasswordDialog() async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Definir Senha de Proteção',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Defina uma senha para que ninguém consiga acessar seu repertório caso descubra o código por acaso.',
                style: TextStyle(fontSize: 12.5, height: 1.3),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Nova Senha',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Confirmar Senha',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final p1 = passCtrl.text.trim();
                final p2 = confirmCtrl.text.trim();
                if (p1.isEmpty) {
                  setDialogState(
                      () => localError = 'A senha não pode ser vazia.');
                  return;
                }
                if (p1 != p2) {
                  setDialogState(() => localError = 'As senhas não coincidem.');
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                await widget.account.setPassword(p1);
                await widget.sync?.sync();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content:
                          Text('Senha de proteção configurada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Salvar Senha'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasswordOptionsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opções de Senha', style: TextStyle(fontSize: 17)),
        content: const Text(
          'A proteção por senha está ativa para este repertório. Você pode alterar a senha atual ou removê-la.',
          style: TextStyle(fontSize: 13, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await widget.account.removePassword();
              await widget.sync?.sync();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Senha de proteção removida.'),
                  ),
                );
              }
            },
            child: const Text('Remover Senha',
                style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSetPasswordDialog();
            },
            child: const Text('Alterar Senha'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutDialog() async {
    final currentCode = widget.account.syncCode ?? '---';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Sair deste Repertório?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deseja deslogar deste aparelho?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '• As cifras e listas locais serão excluídas deste aparelho para você começar do zero com uma nova chave vazia.\n\n'
              '• O repertório antigo NÃO é apagado da nuvem e você poderá se reconectar a ele a qualquer momento usando a chave $currentCode.',
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dica: Baixe o Cartão de Recuperação em PDF antes de sair para guardar sua chave antiga!',
                      style: TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('Sim, Sair e Limpar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.songs?.clearAll();
      await widget.setlists?.clearAll();
      final newCode = await widget.account.resetToNewAccount();

      if (mounted) {
        setState(() => _loading = false);
        Navigator.pop(context);
        if (kIsWeb) {
          reloadWebPage();
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                'Você saiu do repertório antigo. Novo repertório limpo criado ($newCode)!'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao sair do repertório: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  Future<void> _downloadRecoveryPdf() async {
    await RecoveryPdfService.generateAndDownload(
      account: widget.account,
      context: context,
      songCount: widget.songs?.songs.length,
      setlistCount: widget.setlists?.setlists.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    return ListenableBuilder(
      listenable: widget.account,
      builder: (context, _) {
        final currentCode = widget.account.syncCode ?? '---';
        final syncUrl = widget.account.syncUrl;

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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: _showManualInput
                    ? _buildManualInputView(context, isDark)
                    : _buildQrCodeView(context, isDark, currentCode, syncUrl,
                        isSmallScreen),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Visão 1 (Padrão): QR Code de alta visibilidade, Chave Oculta, PDF e Proteção por Senha
  Widget _buildQrCodeView(
    BuildContext context,
    bool isDark,
    String currentCode,
    String syncUrl,
    bool isSmallScreen,
  ) {
    final isProtected = widget.account.isPasswordProtected;

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
        if (widget.account.isLocked) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Repertório Bloqueado',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      Text(
                        'Informe a senha para autorizar o acesso e sincronizar.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.sync != null) {
                      DialogoDesbloqueioConta.show(
                          context, widget.account, widget.sync!);
                    }
                  },
                  child: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // QR CODE em destaque com fundo branco e contraste nítido
        Center(
          child: Container(
            width: isSmallScreen ? 165.0 : 185.0,
            height: isSmallScreen ? 165.0 : 185.0,
            padding: const EdgeInsets.all(10),
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
              size: isSmallScreen ? 145.0 : 165.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1E1B4B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1E1B4B),
              ),
              errorStateBuilder: (cxt, err) {
                return Center(
                  child: Text(
                    'Código: $currentCode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Instrução amigável
        Text(
          'Aponte a câmera do celular ou tablet para este QR Code para abrir e conectar o mesmo repertório instantaneamente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),

        const SizedBox(height: 8),

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
            margin: const EdgeInsets.only(top: 2, bottom: 6),
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

        // Bloco de Proteção por Senha
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isProtected
                  ? Colors.green.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isProtected ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 18,
                color: isProtected
                    ? Colors.green
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proteção por Senha',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      isProtected
                          ? 'Ativa (bloqueia tentativas incorretas)'
                          : 'Desativada (livre via chave)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isProtected
                            ? Colors.green
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isProtected
                    ? _showPasswordOptionsDialog
                    : _showSetPasswordDialog,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: Text(
                  isProtected ? 'Opções' : 'Definir',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppCores.roxo),
                ),
              ),
            ],
          ),
        ),

        // Botão para Baixar Cartão de Recuperação em PDF
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: BorderSide(
              color: AppCores.roxo.withValues(alpha: 0.5),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _downloadRecoveryPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded,
              size: 18, color: AppCores.roxo),
          label: const Text(
            'Baixar Cartão de Recuperação (PDF)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppCores.roxo,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Opção secundária: Digitar código caso o usuário não possa escanear
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: () {
              setState(() {
                _showManualInput = true;
                _error = null;
              });
            },
            icon: const Icon(Icons.keyboard_outlined, size: 16),
            label: const Text(
              'Não pode usar a câmera? Digitar chave',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        Center(
          child: TextButton.icon(
            onPressed: _showSignOutDialog,
            icon: const Icon(Icons.logout_rounded,
                size: 15, color: Colors.redAccent),
            label: const Text(
              'Sair desta conta / Começar do Zero',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            const Spacer(),
            BotaoGradiente(
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
