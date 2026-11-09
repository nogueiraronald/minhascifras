import 'servico_pedal_bridge_stub.dart'
    if (dart.library.html) 'servico_pedal_bridge_web.dart' as impl;

typedef PedalActionCallback = void Function(String action);

/// Ponte de comunicação para pedais passadores de página Bluetooth no Flutter Web / PWA.
class ServicoPedalBridge {
  static void registrar(PedalActionCallback? callback) {
    impl.registrarPedalActionBridge(callback);
  }
}
