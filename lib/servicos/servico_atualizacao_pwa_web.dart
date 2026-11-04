// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';

Future<void> verificarAtualizacao(BuildContext context) async {
  if (html.window.navigator.onLine == false) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Você está offline. Conecte-se à internet para verificar atualizações.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

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
          Text('Verificando atualizações no servidor...'),
        ],
      ),
      duration: Duration(seconds: 2),
    ),
  );

  try {
    // 1. Consulta version.json no servidor com timestamp anti-cache
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final res = await html.HttpRequest.request(
      'version.json?t=$cacheBuster',
      method: 'GET',
      requestHeaders: {'Cache-Control': 'no-cache, no-store, must-revalidate'},
    );

    if (res.status == 200 && res.responseText != null) {
      final data = jsonDecode(res.responseText!) as Map<String, dynamic>;
      final serverBuild = (data['buildVersion'] ?? data['version'] ?? '').toString();
      final localBuild = (html.window.localStorage['minhas_cifras_active_version'] ??
              js.context['minhasCifrasBuildVersion'] ??
              '')
          .toString();

      final pendingUpdate = html.window.localStorage['mc_pending_update'] == 'true';

      if ((serverBuild.isNotEmpty && serverBuild != localBuild) || pendingUpdate) {
        messenger.hideCurrentSnackBar();
        if (context.mounted) {
          final shouldUpdate = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.system_update_rounded, color: Colors.deepPurpleAccent),
                  SizedBox(width: 10),
                  Text('Nova Versão Pronta!'),
                ],
              ),
              content: const Text(
                'Uma nova versão do Minhas Cifras está disponível.\n\n'
                'Ao atualizar agora, todos os seus dados e músicas continuarão salvos e a versão mais recente será carregada.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Mais Tarde'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Atualizar Agora'),
                ),
              ],
            ),
          );

          if (shouldUpdate == true) {
            html.window.localStorage['minhas_cifras_active_version'] = serverBuild;
            html.window.localStorage.remove('mc_pending_update');
            html.window.location.reload();
            return;
          }
        }
        return;
      }
    }
  } catch (e) {
    debugPrint('Aviso ao verificar version.json: $e');
  }

  // Se já estiver na versão mais recente
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(
      content: Text('✓ O Minhas Cifras já está na versão mais recente!'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 3),
    ),
  );
}
