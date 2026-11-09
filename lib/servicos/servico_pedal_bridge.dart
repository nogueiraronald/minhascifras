import 'servico_pedal_bridge_stub.dart'
    if (dart.library.html) 'servico_pedal_bridge_web.dart' as impl;

typedef PedalActionCallback = void Function(String action);
typedef PedalDebugCallback = void Function(String info);

/// Ponte de comunicação para pedais passadores de página Bluetooth no Flutter Web / PWA.
class ServicoPedalBridge {
  static void registrar(PedalActionCallback? callback) {
    impl.registrarPedalActionBridge(callback);
  }

  static void registrarDebug(PedalDebugCallback? callback) {
    impl.registrarPedalDebugBridge(callback);
  }

  static String obterUltimoDebug() {
    return impl.obterUltimoDebugBridge();
  }
}
