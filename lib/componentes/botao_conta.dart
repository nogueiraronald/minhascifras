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
          case AccountStatus.locked:
            const tooltipLocked = 'Repertório Bloqueado por Senha';
            if (compact) {
              return IconButton(
                tooltip: tooltipLocked,
                icon: const Icon(Icons.lock_rounded, color: Colors.amber),
                onPressed: () => _openDialog(context),
              );
            }
            return TextButton.icon(
              onPressed: () => _openDialog(context),
              icon: const Icon(Icons.lock_rounded, color: Colors.amber),
              label: const Text('Bloqueado',
                  style: TextStyle(color: Colors.amber, fontSize: 13)),
            );
          case AccountStatus.signedOut:
          case AccountStatus.ready:
          case AccountStatus.error:
            final isOk = account.status == AccountStatus.ready;
            final labelText = account.userEmail ?? account.syncCode ?? 'Entrar';
            final tooltip = account.userEmail != null
                ? 'Conectado como ${account.userEmail}'
                : (account.syncCode != null
                    ? 'Sincronização Ativa (${account.syncCode})'
                    : 'Acessar com E-mail e Senha');

            if (compact) {
              return IconButton(
                tooltip: tooltip,
                icon: Icon(
                  account.isLoggedIn
                      ? Icons.cloud_done_rounded
                      : (isOk ? Icons.cloud_outlined : Icons.cloud_off_outlined),
                  color: account.isLoggedIn
                      ? Colors.green
                      : (isOk ? Colors.white70 : Colors.amber),
                ),
                onPressed: () => _openDialog(context),
              );
            }

            return TextButton.icon(
              onPressed: () => _openDialog(context),
              icon: Icon(
                account.isLoggedIn
                    ? Icons.cloud_done_rounded
                    : (isOk ? Icons.cloud_outlined : Icons.cloud_off_outlined),
                color: account.isLoggedIn
                    ? Colors.green
                    : (isOk ? Colors.white70 : Colors.amber),
              ),
              label: Text(
                labelText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
        }
      },
    );
  }
}
