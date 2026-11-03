import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'servico_autenticacao_desktop.dart';

class AuthUserInfo {
  AuthUserInfo({required this.email, required this.authHeaders});
  final String email;
  final Map<String, String> authHeaders;
}

/// Serviço de autenticação Google multiplataforma (Web, Android, iOS e macOS Desktop).
class GoogleAuthService {
  GoogleAuthService()
      : _google = !isDesktop
            ? GoogleSignIn(
                scopes: const ['https://www.googleapis.com/auth/drive.file'],
              )
            : null;

  final GoogleSignIn? _google;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  String? _desktopEmail;
  Map<String, String>? _desktopHeaders;

  String? get currentEmail {
    if (isDesktop) return _desktopEmail;
    return _google?.currentUser?.email;
  }

  bool get isSignedIn => currentEmail != null;

  Future<AuthUserInfo?> signInSilently() async {
    if (isDesktop) {
      final user = await DesktopAuthService.restoreSession();
      if (user != null) {
        _desktopEmail = user.email;
        _desktopHeaders = user.authHeaders;
        return AuthUserInfo(email: user.email, authHeaders: user.authHeaders);
      }
      return null;
    }

    try {
      final u = await _google?.signInSilently();
      if (u != null) {
        return AuthUserInfo(email: u.email, authHeaders: await u.authHeaders);
      }
    } catch (_) {}
    return null;
  }

  Future<AuthUserInfo?> signIn({String? desktopClientId}) async {
    if (isDesktop) {
      final user = await DesktopAuthService.signInWithBrowser(clientId: desktopClientId);
      if (user != null) {
        _desktopEmail = user.email;
        _desktopHeaders = user.authHeaders;
        return AuthUserInfo(email: user.email, authHeaders: user.authHeaders);
      }
      return null;
    }

    final u = await _google?.signIn();
    if (u != null) {
      return AuthUserInfo(email: u.email, authHeaders: await u.authHeaders);
    }
    return null;
  }

  Future<AuthUserInfo> signInDirectToken({
    required String accessToken,
    required String email,
  }) async {
    final user = await DesktopAuthService.signInWithDirectToken(
      accessToken: accessToken,
      email: email,
    );
    _desktopEmail = user.email;
    _desktopHeaders = user.authHeaders;
    return AuthUserInfo(email: user.email, authHeaders: user.authHeaders);
  }

  Future<void> signOut() async {
    if (isDesktop) {
      await DesktopAuthService.signOut();
      _desktopEmail = null;
      _desktopHeaders = null;
    } else {
      await _google?.signOut();
    }
  }

  Future<Map<String, String>> authHeaders() async {
    if (isDesktop) {
      if (_desktopHeaders != null) return _desktopHeaders!;
      final user = DesktopAuthService.currentUser;
      if (user != null) return user.authHeaders;
      throw StateError('Usuário não está logado no desktop.');
    }

    final u = _google?.currentUser;
    if (u == null) throw StateError('Usuário não está logado.');
    return u.authHeaders;
  }
}
