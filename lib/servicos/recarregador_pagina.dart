import 'recarregador_pagina_stub.dart'
    if (dart.library.html) 'recarregador_pagina_web.dart' as impl;

/// Recarrega a página no ambiente Web (PWA / Browser) ou opera como no-op nas demais plataformas.
void reloadWebPage() {
  impl.reloadWebPage();
}
