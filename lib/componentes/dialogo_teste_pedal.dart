import 'dart:convert';

import 'package:flutter/material.dart';

import '../servicos/servico_pedal_bridge.dart';

/// Diálogo de diagnóstico do pedal Bluetooth.
/// Mostra, em tempo real, cada tecla que o navegador entrega ao app e a ação reconhecida.
/// Enquanto aberto, o pedal NÃO navega pelas cifras (apenas testa).
class DialogoTestePedal extends StatefulWidget {
  const DialogoTestePedal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const DialogoTestePedal(),
    );
  }

  @override
  State<DialogoTestePedal> createState() => _DialogoTestePedalState();
}

class _DialogoTestePedalState extends State<DialogoTestePedal> {
  final List<String> _eventos = [];
  String _ultimaAcao = '–';
  int _acoes = 0;

  @override
  void initState() {
    super.initState();
    // Fica no topo da pilha: o pedal só testa, sem trocar de música.
    ServicoPedalBridge.registrar(_onAcao);
    ServicoPedalBridge.registrarDebug(_onDebug);
    // Pede ao navegador para (re)assumir o foco do receptor de teclas.
    ServicoPedalBridge.reassumirFoco();
  }

  @override
  void dispose() {
    ServicoPedalBridge.registrarDebug(null);
    ServicoPedalBridge.desregistrar(_onAcao);
    super.dispose();
  }

  void _onAcao(String acao) {
    if (!mounted) return;
    setState(() {
      _acoes++;
      _ultimaAcao = _traduzir(acao);
    });
  }

  void _onDebug(String info) {
    if (!mounted) return;
    String linha = info;
    try {
      final m = jsonDecode(info) as Map<String, dynamic>;
      linha = '${m['time'] ?? ''}  ${m['type']}  tecla="${m['key']}"  '
          'código=${m['keyCode']}  →  ${m['action']}';
    } catch (_) {}
    setState(() {
      _eventos.insert(0, linha);
      if (_eventos.length > 8) _eventos.removeLast();
    });
  }

  String _traduzir(String acao) {
    switch (acao) {
      case 'next':
        return 'PRÓXIMA CIFRA ▶';
      case 'prev':
        return '◀ CIFRA ANTERIOR';
      case 'down':
        return 'ROLAR PARA BAIXO ▼';
      case 'up':
        return 'ROLAR PARA CIMA ▲';
      case 'space':
        return 'ESPAÇO';
      case 'enter':
        return 'ENTER';
      default:
        return acao;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recebeu = _eventos.isNotEmpty;
    return AlertDialog(
      title: const Text('Testar pedal'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Toque na tela uma vez e depois pise no pedal. '
                'Cada pisada deve aparecer abaixo.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: (recebeu ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _ultimaAcao,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recebeu
                          ? 'Ações reconhecidas: $_acoes'
                          : 'Nenhuma tecla recebida ainda…',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Últimas teclas recebidas pelo navegador:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (_eventos.isEmpty)
                const Text(
                  'Se nada aparecer ao pisar, o iPad/navegador não está '
                  'entregando as teclas do pedal ao app. Verifique o modo do '
                  'pedal (setas ← → ou PageUp/PageDown) e se ele está conectado.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                for (final e in _eventos)
                  Text(e,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

