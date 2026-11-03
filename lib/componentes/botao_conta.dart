import 'package:flutter/material.dart';

import '../dados/controlador_conta.dart';

class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.account,
    this.compact = false,
  });

  final AccountController account;
  final bool compact;

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abrindo navegador para você fazer login no Google...'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      await account.signIn();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conectado como ${account.email}! Sincronizando cifras com sua planilha...'),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível conectar ao Google: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        switch (account.status) {
          case AccountStatus.working:
            return const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          case AccountStatus.signedOut:
            if (compact) {
              return IconButton(
                tooltip: 'Entrar com o Google (abrir navegador)',
                icon: const Icon(Icons.cloud_outlined),
                onPressed: () => _handleSignIn(context),
              );
            }
            return TextButton.icon(
              onPressed: () => _handleSignIn(context),
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Entrar'),
            );
          case AccountStatus.ready:
          case AccountStatus.error:
            return IconButton(
              tooltip: account.email ?? 'Conta Google',
              icon: Icon(
                account.status == AccountStatus.ready
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: account.status == AccountStatus.ready ? Colors.green : Colors.red,
              ),
              onPressed: () => _showInfo(context),
            );
        }
      },
    );
  }

  String _formatError(String? err) {
    if (err == null || err.isEmpty) return 'Erro desconhecido ao conectar.';
    final lower = err.toLowerCase();
    if (lower.contains('429') || lower.contains('quota') || lower.contains('rate_limit')) {
      return 'Limite de requisições do Google atingido temporariamente. Aguarde alguns instantes e tente novamente.';
    }
    return err;
  }

  void _showInfo(BuildContext context) {
    final ok = account.status == AccountStatus.ready;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(ok ? Icons.cloud_done : Icons.cloud_off, color: ok ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                account.email ?? 'Conta Google',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SingleChildScrollView(
            child: Text(
              ok
                  ? 'Conectado com sucesso!\nO backup e sincronização com o Google Drive estão ativos.'
                  : 'Não foi possível conectar:\n${_formatError(account.error)}',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              account.signOut();
            },
            child: const Text('Sair / Desconectar', style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
          if (!ok)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                account.retry();
              },
              child: const Text('Tentar de novo', style: TextStyle(fontSize: 13)),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
