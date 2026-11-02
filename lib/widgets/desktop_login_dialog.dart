import 'package:flutter/material.dart';

import '../data/account_controller.dart';
import '../services/desktop_auth_service.dart';

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
    final clientId = _clientIdCtrl.text.trim();
    if (clientId.isEmpty) {
      setState(() => _error = 'Informe o Google Client ID (do Google Cloud Console).');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.account.signIn(desktopClientId: clientId);
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
    final isLogged = widget.account.status == AccountStatus.ready;

    if (isLogged) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_done, color: Colors.green),
            SizedBox(width: 8),
            Text('Conta Google Conectada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E-mail: ${widget.account.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Suas cifras e setlists estão sendo sincronizadas automaticamente com sua planilha no Google Drive.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.account.signOut();
              Navigator.pop(context);
            },
            child: const Text('Desconectar / Sair', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_sync, color: Colors.blue),
          SizedBox(width: 8),
          Text('Conectar com o Google'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sincronize suas cifras e setlists entre o Mac, celular e web através de uma planilha própria no Google Drive.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (!_directTokenMode) ...[
              TextField(
                controller: _clientIdCtrl,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Google Client ID (Desktop OAuth)',
                  hintText: 'ex: 123456...apps.googleusercontent.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Criado no Google Cloud Console > Credenciais > ID do cliente OAuth (Aplicativo para computador).',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ] else ...[
              TextField(
                controller: _emailCtrl,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Seu E-mail Google',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenCtrl,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Access Token do Google',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (_loading) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Aguardando autenticação no navegador...'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _directTokenMode = !_directTokenMode),
              child: Text(
                _directTokenMode ? 'Voltar para Login via Navegador' : 'Ou colar Token de Acesso direto',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : (_directTokenMode ? _loginWithToken : _loginWithBrowser),
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Entrar com o Google'),
        ),
      ],
    );
  }
}
