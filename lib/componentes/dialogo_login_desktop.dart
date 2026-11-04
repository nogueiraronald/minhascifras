import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/controlador_conta.dart';
import 'estilo_app.dart';

/// Diálogo de Sincronização em Nuvem via Supabase (sem exigência de login ou senha).
class DesktopLoginDialog extends StatefulWidget {
  const DesktopLoginDialog({super.key, required this.account});

  final AccountController account;

  static Future<void> show(BuildContext context, AccountController account) {
    return showDialog<void>(
      context: context,
      builder: (_) => DesktopLoginDialog(account: account),
    );
  }

  @override
  State<DesktopLoginDialog> createState() => _DesktopLoginDialogState();
}

class _DesktopLoginDialogState extends State<DesktopLoginDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showConnectInput = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectToCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Por favor, digite o código de sincronização.');
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
        _error = e.toString().replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
      });
    }
  }

  Future<void> _generateNewCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerar Novo Código?'),
        content: const Text(
          'Isso criará uma nova chave para este aparelho. O repertório atual continuará salvo localmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gerar Novo'),
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

    return CartaoDialogoModerno(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BadgeIconeGradiente(
                icon: Icons.cloud_sync_rounded,
                size: 46,
                iconSize: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sincronização em Nuvem',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Backup automático no Supabase',
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
          const SizedBox(height: 18),

          // Cartão do Código deste Aparelho
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppCores.roxo.withValues(alpha: isDark ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppCores.roxo.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chave deste dispositivo:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Código $currentCode copiado!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 14, color: AppCores.roxo),
                            SizedBox(width: 4),
                            Text(
                              'Copiar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppCores.roxo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  currentCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppCores.roxo,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suas cifras e setlists são salvas automaticamente na nuvem sem precisar de senha ou cadastro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Seção: Conectar a outro aparelho
          if (!_showConnectInput) ...[
            OutlinedButton.icon(
              onPressed: () => setState(() => _showConnectInput = true),
              icon: const Icon(Icons.devices_rounded, size: 18),
              label: const Text('Conectar a outro celular ou computador'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Digite a chave do outro aparelho para sincronizar o mesmo repertório:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Ex: MC-8492',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BotaoGradiente(
                        onPressed: _loading ? null : _connectToCode,
                        isLoading: _loading,
                        label: 'Conectar',
                        icon: Icons.link_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12, height: 1.3),
              ),
            ),
          ],

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _generateNewCode,
                child: Text(
                  'Novo código',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              BotaoGradiente(
                onPressed: () => Navigator.pop(context),
                label: 'Concluído',
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
