import 'package:flutter/material.dart';
import 'servico_atualizacao_pwa_stub.dart'
    if (dart.library.html) 'servico_atualizacao_pwa_web.dart' as impl;

/// Serviço de verificação e aplicação de atualizações do Minhas Cifras (PWA e Desktop).
class ServicoAtualizacaoPwa {
  /// Verifica se há atualizações disponíveis no servidor e oferece atualização suave.
  static Future<void> verificarAtualizacao(BuildContext context) async {
    await impl.verificarAtualizacao(context);
  }

  /// Verifica ao iniciar o app e, se houver nova versão, força a atualização imediatamente sem esperar o usuário.
  static Future<void> verificarEForcarAtualizacaoAoIniciar() async {
    await impl.verificarEForcarAtualizacaoAoIniciar();
  }
}
