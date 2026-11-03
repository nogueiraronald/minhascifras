import 'package:flutter/material.dart';

import '../dados/controlador_conta.dart';
import 'estilo_app.dart';

/// Diálogo de login seguro com Conta Google (Web e Desktop).
/// O Google Client ID é 100% interno e transparente para o usuário.
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
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.account.signIn();
      if (!mounted) return;
      if (widget.account.status == AccountStatus.ready) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Conectado como ${widget.account.email}! Sincronizando cifras...'),
            backgroundColor: Colors.green[800],
          ),
        );
      } else {
        setState(() {
          _loading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLogged = widget.account.status == AccountStatus.ready;

    // Usuário já conectado
    if (isLogged) {
      return CartaoDialogoModerno(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BadgeIconeGradiente(
                  icon: Icons.cloud_done_rounded,
                  size: 44,
                  iconSize: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conta Google Conectada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.account.email ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppCores.roxo,
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
                'Suas cifras e setlists estão sincronizadas com segurança com o seu Google Drive.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.account.signOut();
                    Navigator.pop(context);
                  },
                  child: const Text('Desconectar / Sair',
                      style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                BotaoGradiente(
                  onPressed: () => Navigator.pop(context),
                  label: 'Fechar',
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Usuário não conectado
    return CartaoDialogoModerno(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BadgeIconeGradiente(
                icon: Icons.cloud_sync_rounded,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conectar com o Google',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sincronize seu repertório na nuvem',
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppCores.roxo.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppCores.roxo.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppCores.roxo, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Faça login com sua Conta Google com total segurança e sem nenhum custo.\n\n'
                    'Suas cifras e setlists ficam salvas na nuvem para você acessar de qualquer aparelho.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                    color: Colors.red, fontSize: 12, height: 1.3),
              ),
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Conectando ao Google...', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BotaoGradiente(
                onPressed: _loading ? null : _login,
                isLoading: _loading,
                icon: Icons.login_rounded,
                label: 'Entrar com Google',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
