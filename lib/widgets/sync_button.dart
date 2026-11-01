import 'package:flutter/material.dart';

import '../data/account_controller.dart';
import '../services/sync_service.dart';

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
        return IconButton(
          tooltip: sync.error ?? 'Sincronizar agora',
          icon: Icon(sync.error == null ? Icons.sync : Icons.sync_problem),
          onPressed: () => sync.sync(),
        );
      },
    );
  }
}
