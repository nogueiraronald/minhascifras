import 'servico_wakelock_stub.dart'
    if (dart.library.html) 'servico_wakelock_web.dart' as impl;

/// Serviço responsável por manter a tela acesa (Screen Wake Lock)
/// enquanto o músico estiver exibindo as cifras, evitando que o celular,
/// tablet ou computador bloqueie/apague a tela por inatividade.
class ServicoWakeLock {
  static bool _ativo = false;

  /// Indica se a proteção contra bloqueio de tela está ativa.
  static bool get estaAtivo => _ativo;

  /// Ativa ou desativa a manutenção de tela acesa.
  static Future<void> manterTelaAtiva(bool ativo) async {
    _ativo = ativo;
    await impl.definirWakeLock(ativo);
  }
}

