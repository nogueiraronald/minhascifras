import 'package:flutter/material.dart';

import '../dados/controlador_conta.dart';
import '../servicos/servico_sincronizacao.dart';

class SyncButton extends StatelessWidget {
  const SyncButton({super.key, required this.sync, required this.account});

  final SyncService sync;
  final AccountController account;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sync, account]),
      builder: (context, _) {
        if (account.status != AccountStatus.ready) return const SizedBox.shrink();
        if (sync.syncing) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final hasError = sync.error != null;
        return IconButton(
          tooltip: hasError ? 'Aviso de sincronização' : 'Sincronizar agora',
          icon: Icon(
            hasError ? Icons.sync_problem : Icons.sync,
            color: hasError ? Colors.amber[700] : null,
          ),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text('Sincronizando com a Nuvem...'),
                  ],
                ),
                duration: Duration(seconds: 4),
              ),
            );

            await sync.sync();

            if (context.mounted) {
              messenger.hideCurrentSnackBar();
              if (sync.error != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(sync.error!, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.red[800],
                    duration: const Duration(seconds: 5),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('✓ Sincronizado com a Nuvem com sucesso!'),
                    backgroundColor: Colors.green[700],
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
