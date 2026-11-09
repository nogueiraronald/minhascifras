import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servicos/servico_pedal_bridge.dart';
import 'estilo_app.dart';

/// Modal interativo para teste em tempo real, detecção de sinal Bluetooth e
/// guia de configuração para pedais passadores de página (M-VAVE VAVE368, PageFlip, AirTurn).
class DialogoDiagnosticoPedal extends StatefulWidget {
  const DialogoDiagnosticoPedal({
    super.key,
    required this.onTriggerAction,
  });

  final void Function(String action) onTriggerAction;

  static Future<void> show(
    BuildContext context, {
    required void Function(String action) onTriggerAction,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogoDiagnosticoPedal(
        onTriggerAction: onTriggerAction,
      ),
    );
  }

  @override
  State<DialogoDiagnosticoPedal> createState() =>
      _DialogoDiagnosticoPedalState();
}

class _DialogoDiagnosticoPedalState extends State<DialogoDiagnosticoPedal> {
  String _ultimoSinal = 'Aguardando toque no pedal...';
  String _detalhes = 'Pise no pedal M-VAVE para ver o código recebido.';
  String? _ultimaAcao;
  DateTime? _ultimoTimestamp;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    ServicoPedalBridge.registrarDebug(_handleBridgeDebug);

    final ultimo = ServicoPedalBridge.obterUltimoDebug();
    if (ultimo.isNotEmpty) {
      _processarDebugString(ultimo);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    ServicoPedalBridge.registrarDebug(null);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      setState(() {
        _ultimoTimestamp = DateTime.now();
        final keyLabel = event.logicalKey.keyLabel;
        final keyId = event.logicalKey.keyId;
        _ultimoSinal = 'Tecla: $keyLabel (ID: $keyId)';
        _detalhes = 'Origem: HardwareKeyboard (Flutter)';
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.numpad6 ||
            event.logicalKey == LogicalKeyboardKey.bracketRight) {
          _ultimaAcao = 'Próxima Música (⇨)';
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.numpad4 ||
            event.logicalKey == LogicalKeyboardKey.bracketLeft) {
          _ultimaAcao = 'Música Anterior (⇦)';
        } else if (event.logicalKey == LogicalKeyboardKey.pageDown ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _ultimaAcao = 'Rolar para Baixo (⇩)';
        } else if (event.logicalKey == LogicalKeyboardKey.pageUp ||
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _ultimaAcao = 'Rolar para Cima (⇧)';
        } else {
          _ultimaAcao = 'Tecla detectada';
        }
      });
    }
    return false;
  }

  void _handleBridgeDebug(String jsonString) {
    _processarDebugString(jsonString);
  }

  void _processarDebugString(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _ultimoTimestamp = DateTime.now();
        final key = data['key']?.toString() ?? '';
        final code = data['code']?.toString() ?? '';
        final keyCode = data['keyCode']?.toString() ?? '';
        final action = data['action']?.toString() ?? '';
        final type = data['type']?.toString() ?? '';

        if (type == 'mouse_context') {
          _ultimoSinal = 'Clique do Pedal (Modo Mouse / Botão 2)';
          _detalhes = 'M-VAVE Modo 4 detectado';
          _ultimaAcao = 'Próxima Música (⇨)';
        } else {
          _ultimoSinal = 'Key: "$key" | Code: "$code" | KeyCode: $keyCode';
          _detalhes = 'Origem: Web/iPadOS Safari Bridge';
          if (action == 'next') {
            _ultimaAcao = 'Próxima Música (⇨)';
          } else if (action == 'prev') {
            _ultimaAcao = 'Música Anterior (⇦)';
          } else if (action == 'down') {
            _ultimaAcao = 'Rolar Baixo (⇩)';
          } else if (action == 'up') {
            _ultimaAcao = 'Rolar Cima (⇧)';
          } else {
            _ultimaAcao = action.isNotEmpty ? action : 'Recebido';
          }
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF161822) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppCores.roxo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_input_component,
                color: AppCores.roxo, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pedal Passador de Cifras',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Caixa de Detecção ao Vivo
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F111A)
                      : const Color(0xFFF1F3F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _ultimaAcao != null
                        ? AppCores.roxo.withValues(alpha: 0.6)
                        : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _ultimaAcao != null
                              ? Icons.sensors
                              : Icons.sensors_off_outlined,
                          color: _ultimaAcao != null
                              ? Colors.greenAccent
                              : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ultimaAcao != null
                              ? 'Sinal Detectado!'
                              : 'Monitor em Tempo Real',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _ultimaAcao != null
                                ? Colors.greenAccent
                                : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (_ultimoTimestamp != null)
                          Text(
                            '${_ultimoTimestamp!.hour.toString().padLeft(2, '0')}:${_ultimoTimestamp!.minute.toString().padLeft(2, '0')}:${_ultimoTimestamp!.second.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ultimoSinal,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detalhes,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    if (_ultimaAcao != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppCores.roxo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppCores.roxo, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Ação: $_ultimaAcao',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppCores.roxo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botões de Teste Manual do Indicador Flutuante
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onTriggerAction('prev');
                        setState(() => _ultimaAcao = 'Música Anterior (⇦)');
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Testar ⇦'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onTriggerAction('next');
                        setState(() => _ultimaAcao = 'Próxima Música (⇨)');
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Testar ⇨'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Instruções para M-VAVE VAVE368 / Chocolate
              Text(
                'Guia Rápido: M-VAVE VAVE368',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildDicaItem(
                '1. Chave Seletora (I / A)',
                'A chave física lateral do pedal DEVE estar na posição "I" (iOS / iPadOS). Se estiver em "A", o iPad ignora o sinal.',
                Icons.toggle_on_outlined,
              ),
              const SizedBox(height: 6),
              _buildDicaItem(
                '2. Modos do Pedal (Botão MODE)',
                '• Modo 2 (Recomendado): Seta Esquerda/Direita para trocar músicas com o cursor ⇨ / ⇦.\n'
                '• Modo 1: PageUp/PageDown rola a página e troca no fim.\n'
                '• Modo 4 (Mouse): Dispara cliques laterais no app.',
                Icons.music_note_rounded,
              ),
              const SizedBox(height: 6),
              _buildDicaItem(
                '3. Toque nas Bordas no iPad',
                'Você também pode tocar nas extremidades esquerda e direita da tela da cifra para avançar ou voltar músicas.',
                Icons.touch_app_outlined,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _buildDicaItem(String titulo, String descricao, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppCores.roxo),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descricao,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

