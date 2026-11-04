import 'package:flutter/material.dart';

import '../dados/controlador_conta.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../servicos/servico_sincronizacao.dart';
import 'dialogo_login_desktop.dart';

/// Botão de status e acesso à sincronização em nuvem (Supabase).
class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.account,
    this.songs,
    this.setlists,
    this.sync,
    this.compact = false,
  });

  final AccountController account;
  final SongRepository? songs;
  final SetlistRepository? setlists;
  final SyncService? sync;
  final bool compact;

  void _openDialog(BuildContext context) {
    DesktopLoginDialog.show(
      context,
      account,
      songs: songs,
      setlists: setlists,
      sync: sync,
    );
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
          case AccountStatus.ready:
          case AccountStatus.error:
            final isOk = account.status == AccountStatus.ready;
            final tooltip = account.syncCode != null
                ? 'Sincronização Ativa (${account.syncCode})'
                : 'Sincronização em Nuvem';

            if (compact) {
              return IconButton(
                tooltip: tooltip,
                icon: Icon(
                  isOk ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: isOk ? Colors.green : Colors.amber,
                ),
                onPressed: () => _openDialog(context),
              );
            }

            return TextButton.icon(
              onPressed: () => _openDialog(context),
              icon: Icon(
                isOk ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: isOk ? Colors.green : Colors.amber,
              ),
              label: Text(account.syncCode ?? 'Nuvem'),
            );
        }
      },
    );
  }
}
