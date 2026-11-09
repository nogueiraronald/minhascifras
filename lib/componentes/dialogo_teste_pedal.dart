import 'dart:convert';

import 'package:flutter/material.dart';

import '../servicos/servico_pedal_bridge.dart';

/// Diálogo de diagnóstico do pedal Bluetooth.
/// Mostra, em tempo real, cada tecla ou movimento de cursor que o navegador entrega ao app
/// e a ação reconhecida. Enquanto aberto, o pedal NÃO navega pelas cifras (apenas testa).
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
  bool _canalAtivo = true;

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
    ServicoPedalBridge.reassumirFoco();
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

  void _simularAcao(String acao, String origem) {
    ServicoPedalBridge.reassumirFoco();
    final hora = TimeOfDay.now().format(context);
    setState(() {
      _canalAtivo = true;
      _acoes++;
      _ultimaAcao = _traduzir(acao);
      _eventos.insert(0, '$hora  $origem  →  $acao');
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
    final recebeu = _eventos.isNotEmpty || _acoes > 0;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.keyboard_alt_outlined, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Testar pedal')),
          if (recebeu)
            TextButton(
              onPressed: () {
                ServicoPedalBridge.reassumirFoco();
                setState(() {
                  _eventos.clear();
                  _acoes = 0;
                  _ultimaAcao = '–';
                });
              },
              child: const Text('Limpar'),
            ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pise no pedal agora ou toque nos botões abaixo para testar '
                'e ativar o canal Bluetooth do iPad.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ServicoPedalBridge.reassumirFoco();
                    final hora = TimeOfDay.now().format(context);
                    setState(() {
                      _canalAtivo = true;
                      _eventos.insert(
                        0,
                        '$hora  canal_ativado  cursor="Te|ste"  →  pronto',
                      );
                      if (_eventos.length > 8) _eventos.removeLast();
                    });
                  },
                  icon: Icon(
                    _canalAtivo
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 18,
                  ),
                  label: const Text('Ativar / Focar Canal do Pedal'),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: (recebeu ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _ultimaAcao,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recebeu
                          ? 'Ações reconhecidas: $_acoes'
                          : 'Aguardando pisada no pedal…',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _simularAcao('prev', 'teste_toque'),
                    child: const Text('◀ Voltar'),
                  ),
                  OutlinedButton(
                    onPressed: () => _simularAcao('next', 'teste_toque'),
                    child: const Text('Próxima ▶'),
                  ),
                  OutlinedButton(
                    onPressed: () => _simularAcao('up', 'teste_toque'),
                    child: const Text('▲ Subir'),
                  ),
                  OutlinedButton(
                    onPressed: () => _simularAcao('down', 'teste_toque'),
                    child: const Text('▼ Descer'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Últimas teclas / movimentos recebidos:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (_eventos.isEmpty)
                const Text(
                  'Toque em "Ativar / Focar Canal do Pedal" acima e pise no pedal. '
                  'Suporta modo Avançar/Voltar (← →) e Subir/Descer (↑ ↓ / PageUp / PageDown).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                for (final e in _eventos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ServicoPedalBridge.reassumirFoco();
            Navigator.pop(context);
          },
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
