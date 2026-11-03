import 'package:flutter/material.dart';

import '../configuracao/configuracao_app.dart';
import '../dados/controlador_conta.dart';
import '../servicos/servico_autenticacao_desktop.dart';
import 'estilo_app.dart';

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
  final _clientIdCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _directTokenMode = false;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    DesktopAuthService.getSavedClientId().then((val) {
      if (mounted && val.isNotEmpty) {
        _clientIdCtrl.text = val;
      }
    });
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _tokenCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithBrowser() async {
    final inputId = _clientIdCtrl.text.trim();
    final effectiveClientId = inputId.isNotEmpty ? inputId : null;

    if (effectiveClientId == null && AppConfig.googleClientId.contains('placeholder')) {
      setState(() {
        _error = 'Onde colocar o ID:\n'
            '1. Cole o seu Client ID no campo de texto abaixo; OU\n'
            '2. No arquivo lib/configuracao/configuracao_app.dart, substitua a linha 15 pelo seu Client ID.';
        _showHelp = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.account.signIn(desktopClientId: effectiveClientId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conectado como ${widget.account.email}! Sincronizando...')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
      });
    }
  }

  Future<void> _loginWithToken() async {
    final token = _tokenCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (token.isEmpty || email.isEmpty) {
      setState(() => _error = 'Preencha o Token e o E-mail.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.account.signInDirectToken(accessToken: token, email: email);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLogged = widget.account.status == AccountStatus.ready;

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
                'Suas cifras e listas estão sincronizadas com segurança com o Google Drive.',
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
                  child: const Text('Desconectar / Sair', style: TextStyle(color: Colors.red)),
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

    return CartaoDialogoModerno(
      width: 480,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppCores.roxo.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppCores.roxo.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_open_rounded, color: AppCores.roxo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O aplicativo abrirá o seu navegador para você digitar seu e-mail e senha do Google com total segurança.\n\n'
                    'Após a aprovação, suas cifras locais são sincronizadas com sua planilha no Google Drive sem duplicidade.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!_directTokenMode) ...[
            if (_showHelp) ...[
              const Text(
                'Client ID personalizado (opcional):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _clientIdCtrl,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'Google Client ID (Desktop)',
                  hintText: 'Padrão integrado do aplicativo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.key, size: 18),
                  isDense: true,
                  suffixIcon: _clientIdCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _clientIdCtrl.clear()),
                        )
                      : null,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 8),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _showHelp = !_showHelp),
              child: Row(
                children: [
                  Icon(
                    _showHelp ? Icons.keyboard_arrow_up : Icons.tune,
                    size: 16,
                    color: AppCores.roxo,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showHelp ? 'Ocultar opções avançadas' : 'Opções avançadas (personalizar Client ID)',
                    style: const TextStyle(fontSize: 12, color: AppCores.roxo, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: _emailCtrl,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: 'Seu E-mail Google',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenCtrl,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: 'Access Token do Google',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
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
          if (_loading) ...[
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Aguardando aprovação no seu navegador...', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : () => setState(() => _directTokenMode = !_directTokenMode),
              child: Text(
                _directTokenMode ? 'Voltar para Login via Navegador' : 'Ou colar Token de Acesso direto',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                onPressed: _loading
                    ? null
                    : (_directTokenMode ? _loginWithToken : _loginWithBrowser),
                isLoading: _loading,
                icon: Icons.open_in_browser_rounded,
                label: 'Fazer Login no Navegador',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
