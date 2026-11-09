import 'servico_pedal_bridge_stub.dart'
    if (dart.library.html) 'servico_pedal_bridge_web.dart' as impl;

typedef PedalActionCallback = void Function(String action);
typedef PedalDebugCallback = void Function(String info);

/// Ponte de comunicação para pedais passadores de página Bluetooth no Flutter Web / PWA.
class ServicoPedalBridge {
  /// Registra ou eleva o listener para o topo da pilha de receptores ativos.
  static void registrar(PedalActionCallback? callback) {
    if (callback != null) {
      impl.registrarPedalActionBridge(callback);
    }
  }

  /// Remove o listener específico da pilha ao fechar uma tela, restaurando o anterior.
  static void desregistrar(PedalActionCallback? callback) {
    if (callback != null) {
      impl.desregistrarPedalActionBridge(callback);
    }
  }

  static void registrarDebug(PedalDebugCallback? callback) {
    impl.registrarPedalDebugBridge(callback);
  }

  static String obterUltimoDebug() {
    return impl.obterUltimoDebugBridge();
  }
}
