typedef PedalActionCallback = void Function(String action);

void registrarPedalActionBridge(PedalActionCallback? callback) {
  // No-op em plataformas não-web (utilizam HardwareKeyboard diretamente)
}
