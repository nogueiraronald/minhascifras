// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

typedef PedalActionCallback = void Function(String action);
typedef PedalDebugCallback = void Function(String info);

final List<PedalActionCallback> _actionListeners = [];
PedalDebugCallback? _debugCallback;
StreamSubscription<html.Event>? _actionSub;
StreamSubscription<html.Event>? _debugSub;
String _ultimoDebug = '';

void _ensureActionSubscription() {
  if (_actionSub != null) return;
  _actionSub = html.window.on['pedalaction'].listen((event) {
    if (event is html.CustomEvent && event.detail != null) {
      final action = event.detail.toString();
      if (_actionListeners.isNotEmpty) {
        // Envia para o listener no topo da pilha (leitor ativo no momento)
        _actionListeners.last(action);
      }
    }
  });
}

void registrarPedalActionBridge(PedalActionCallback? callback) {
  _ensureActionSubscription();
  if (callback != null) {
    _actionListeners.remove(callback);
    _actionListeners.add(callback);
  }
}

void desregistrarPedalActionBridge(PedalActionCallback? callback) {
  if (callback != null) {
    _actionListeners.remove(callback);
  }
}

void registrarPedalDebugBridge(PedalDebugCallback? callback) {
  _debugCallback = callback;
  _debugSub ??= html.window.on['pedaldebug'].listen((event) {
    if (event is html.CustomEvent && event.detail != null) {
      _ultimoDebug = event.detail.toString();
      _debugCallback?.call(_ultimoDebug);
    }
  });
}

String obterUltimoDebugBridge() {
  return _ultimoDebug;
}
