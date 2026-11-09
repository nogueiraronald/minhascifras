typedef PedalActionCallback = void Function(String action);
typedef PedalDebugCallback = void Function(String info);

void registrarPedalActionBridge(PedalActionCallback? callback) {
  // No-op em plataformas não-web
}

void registrarPedalDebugBridge(PedalDebugCallback? callback) {
  // No-op em plataformas não-web
}

String obterUltimoDebugBridge() {
  return '';
}
