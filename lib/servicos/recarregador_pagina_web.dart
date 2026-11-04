// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Recarrega a página no ambiente Web usando o objeto nativo window.location.
void reloadWebPage() {
  html.window.location.reload();
}
