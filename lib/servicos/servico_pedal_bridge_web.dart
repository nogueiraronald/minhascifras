// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

typedef PedalActionCallback = void Function(String action);
typedef PedalDebugCallback = void Function(String info);

StreamSubscription<html.Event>? _actionSub;
StreamSubscription<html.Event>? _debugSub;
String _ultimoDebug = '';

void registrarPedalActionBridge(PedalActionCallback? callback) {
  _actionSub?.cancel();
  _actionSub = null;
  if (callback != null) {
    _actionSub = html.window.on['pedalaction'].listen((event) {
      if (event is html.CustomEvent && event.detail != null) {
        callback(event.detail.toString());
      }
    });
  }
}

void registrarPedalDebugBridge(PedalDebugCallback? callback) {
  _debugSub?.cancel();
  _debugSub = null;
  if (callback != null) {
    _debugSub = html.window.on['pedaldebug'].listen((event) {
      if (event is html.CustomEvent && event.detail != null) {
        _ultimoDebug = event.detail.toString();
        callback(_ultimoDebug);
      }
    });
  }
}

String obterUltimoDebugBridge() {
  return _ultimoDebug;
}
