import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Login do Google feito pelo próprio usuário (tela do Google, sem senha no app).
/// Escopo mínimo: o app só enxerga arquivos que ele mesmo criou.
class GoogleAuthService {
  GoogleAuthService()
      : _google = isSupported
            ? GoogleSignIn(
                scopes: const ['https://www.googleapis.com/auth/drive.file'],
              )
            : null;

  final GoogleSignIn? _google;

  /// O Google Sign-In oficial do Flutter tem suporte nativo para Web, Android e iOS.
  /// Em plataformas Desktop (macOS, Windows, Linux), o plugin não tem suporte de UI nativa.
  static bool get isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS;
  }

  GoogleSignInAccount? get user => _google?.currentUser;

  Future<GoogleSignInAccount?> signInSilently() async {
    if (!isSupported || _google == null) return null;
    try {
      return await _google.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (!isSupported || _google == null) {
      throw UnsupportedError(
        'O login com Google para sincronização em nuvem está disponível nas plataformas Web, Android e iOS.\n\n'
        'No macOS Desktop, o aplicativo armazena suas cifras localmente com suporte offline completo e exportação/importação.',
      );
    }
    try {
      return await _google.signIn();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_google != null) {
      try {
        await _google.signOut();
      } catch (_) {}
    }
  }

  /// Cabeçalhos com o token do usuário (Authorization: Bearer ...).
  Future<Map<String, String>> authHeaders() async {
    final u = user;
    if (u == null) throw StateError('Usuário não está logado.');
    return u.authHeaders;
  }
}
