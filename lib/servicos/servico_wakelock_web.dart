// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

bool _desejadoAtivo = false;
bool _listenersRegistrados = false;

Future<void> definirWakeLock(bool ativo) async {
  _desejadoAtivo = ativo;
  _garantirListeners();

  // Aciona o gerenciador global de Screen Wake Lock no index.html
  try {
    if (js.context.hasProperty('setMinhasCifrasWakeLock')) {
      js.context.callMethod('setMinhasCifrasWakeLock', [ativo]);
    }
  } catch (_) {}

  if (ativo) {
    await _solicitarWakeLockNativo();
  }
}

void _garantirListeners() {
  if (_listenersRegistrados) return;
  _listenersRegistrados = true;

  html.document.onVisibilityChange.listen((_) {
    if (html.document.visibilityState == 'visible' && _desejadoAtivo) {
      _solicitarWakeLockNativo();
    }
  });

  html.window.onFocus.listen((_) {
    if (_desejadoAtivo) {
      _solicitarWakeLockNativo();
    }
  });
}

Future<void> _solicitarWakeLockNativo() async {
  if (!_desejadoAtivo) return;
  try {
    final nav = js.JsObject.fromBrowserObject(html.window.navigator);
    final wakeLock = nav['wakeLock'];
    if (wakeLock is js.JsObject) {
      wakeLock.callMethod('request', ['screen']);
    }
  } catch (_) {
    // Alguns navegadores exigem gesto do usuário antes de conceder o WakeLock;
    // o listener global em index.html fará a reaquisição automática no primeiro toque.
  }
}
