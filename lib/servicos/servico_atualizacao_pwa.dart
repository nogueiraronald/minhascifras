import 'package:flutter/material.dart';
import 'servico_atualizacao_pwa_stub.dart'
    if (dart.library.html) 'servico_atualizacao_pwa_web.dart' as impl;

/// Serviço de verificação e aplicação de atualizações do Minhas Cifras (PWA e Desktop).
class ServicoAtualizacaoPwa {
  /// Verifica se há atualizações disponíveis no servidor e oferece atualização suave.
  static Future<void> verificarAtualizacao(BuildContext context) async {
    await impl.verificarAtualizacao(context);
  }
}
