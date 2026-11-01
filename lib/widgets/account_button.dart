import 'package:flutter/material.dart';

import '../data/account_controller.dart';

class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.account});

  final AccountController account;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        switch (account.status) {
          case AccountStatus.working:
            return const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          case AccountStatus.signedOut:
            return TextButton.icon(
              onPressed: account.signIn,
              icon: const Icon(Icons.login),
              label: const Text('Entrar com Google'),
            );
          case AccountStatus.ready:
          case AccountStatus.error:
            return IconButton(
              tooltip: account.email,
              icon: Icon(account.status == AccountStatus.ready
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined),
              onPressed: () => _showInfo(context),
            );
        }
      },
    );
  }

  void _showInfo(BuildContext context) {
    final ok = account.status == AccountStatus.ready;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(account.email ?? 'Conta Google'),
        content: Text(ok ? 'Planilha criada e conectada.' : 'Não foi possível conectar:\n${account.error}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              account.signOut();
            },
            child: const Text('Sair'),
          ),
          if (!ok)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                account.retry();
              },
              child: const Text('Tentar de novo'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }
}
