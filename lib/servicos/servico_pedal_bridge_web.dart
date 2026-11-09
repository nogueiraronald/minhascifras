// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

typedef PedalActionCallback = void Function(String action);

StreamSubscription<html.Event>? _sub;

void registrarPedalActionBridge(PedalActionCallback? callback) {
  _sub?.cancel();
  _sub = null;
  if (callback != null) {
    _sub = html.window.on['pedalaction'].listen((event) {
      if (event is html.CustomEvent && event.detail != null) {
        callback(event.detail.toString());
      }
    });
  }
}
