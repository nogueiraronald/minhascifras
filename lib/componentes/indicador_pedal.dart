import 'dart:async';
import 'package:flutter/material.dart';

/// Tipos de ação executados pelo pedal passador de cifras.
enum TipoAcaoPedal {
  proxima,
  anterior,
  descer,
  subir,
}

/// Controlador reativo que gerencia a exibição do cursor indicador de pedal (HUD).
class ControladorIndicadorPedal extends ChangeNotifier {
  TipoAcaoPedal? _acaoAtual;
  Timer? _timer;

  TipoAcaoPedal? get acaoAtual => _acaoAtual;

  void mostrar(TipoAcaoPedal acao) {
    _acaoAtual = acao;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 650), () {
      _acaoAtual = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Overlay flutuante exibido no centro da tela ao acionar o pedal passador de páginas / cifras.
/// Exibe a seta de direção de alta visibilidade semelhante ao Data Cifras.
class IndicadorPedalOverlay extends StatelessWidget {
  const IndicadorPedalOverlay({
    super.key,
    required this.controller,
  });

  final ControladorIndicadorPedal controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final acao = controller.acaoAtual;
        final visible = acao != null;

        IconData icon;
        switch (acao) {
          case TipoAcaoPedal.proxima:
            icon = Icons.arrow_forward_rounded;
            break;
          case TipoAcaoPedal.anterior:
            icon = Icons.arrow_back_rounded;
            break;
          case TipoAcaoPedal.descer:
            icon = Icons.arrow_downward_rounded;
            break;
          case TipoAcaoPedal.subir:
            icon = Icons.arrow_upward_rounded;
            break;
          case null:
            icon = Icons.arrow_forward_rounded;
            break;
        }

        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xE0111827),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 76,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
