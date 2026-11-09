// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';

/// Versão (build) realmente em execução, injetada no index.html no deploy.
String _versaoEmExecucao() {
  try {
    if (js.context.hasProperty('mcRunningBuild')) {
      return (js.context.callMethod('mcRunningBuild') ?? '').toString();
    }
  } catch (_) {}
  return '';
}

/// Remove Service Worker e caches e recarrega da rede (atualização garantida).
void _aplicarAtualizacao() {
  try {
    if (js.context.hasProperty('mcHardUpdate')) {
      js.context.callMethod('mcHardUpdate');
      return;
    }
  } catch (_) {}
  html.window.location.reload();
}

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
      final localBuild = _versaoEmExecucao();

      // Só considera atualização quando conhecemos a versão em execução e ela difere do servidor
      if (serverBuild.isNotEmpty &&
          localBuild.isNotEmpty &&
          serverBuild != localBuild) {
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
            _aplicarAtualizacao();
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
  final emExecucao = _versaoEmExecucao();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        emExecucao.isEmpty
            ? '✓ O Minhas Cifras já está na versão mais recente!'
            : '✓ Já está na versão mais recente!\nVersão: $emExecucao',
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Ao iniciar, apenas pede ao Service Worker para checar atualização em segundo plano.
/// A recarga automática para nova versão é feita pelo index.html (com proteção contra laço).
Future<void> verificarEForcarAtualizacaoAoIniciar() async {
  if (html.window.navigator.onLine == false) return;
  try {
    if (js.context.hasProperty('forcarAtualizacaoPwa')) {
      js.context.callMethod('forcarAtualizacaoPwa');
    }
  } catch (e) {
    debugPrint('Aviso ao verificar atualização ao iniciar: $e');
  }
}
