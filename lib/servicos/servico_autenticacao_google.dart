import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configuracao/configuracao_app.dart';
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
                clientId: AppConfig.googleClientId,
                scopes: const [
                  'https://www.googleapis.com/auth/drive.file',
                  'email',
                ],
              )
            : null;

  final GoogleSignIn? _google;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  String? _desktopEmail;
  Map<String, String>? _desktopHeaders;

  String? get currentEmail {
    if (_desktopEmail != null) return _desktopEmail;
    final savedUser = DesktopAuthService.currentUser;
    if (savedUser != null) return savedUser.email;
    return _google?.currentUser?.email;
  }

  bool get isSignedIn => currentEmail != null;

  Future<AuthUserInfo?> signInSilently() async {
    // 1. Tenta restaurar sessão salva (funciona tanto em Desktop quanto na Web)
    final user = await DesktopAuthService.restoreSession();
    if (user != null) {
      _desktopEmail = user.email;
      _desktopHeaders = user.authHeaders;
      return AuthUserInfo(email: user.email, authHeaders: user.authHeaders);
    }

    // 2. Se não estiver no desktop, tenta silent sign in pelo GoogleSignIn
    if (!isDesktop) {
      try {
        final u = await _google?.signInSilently();
        if (u != null) {
          return AuthUserInfo(email: u.email, authHeaders: await u.authHeaders);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<AuthUserInfo?> signIn({String? desktopClientId}) async {
    final cleanClientId = (desktopClientId != null && desktopClientId.trim().isNotEmpty)
        ? desktopClientId.trim()
        : AppConfig.googleClientId;

    if (isDesktop) {
      final user = await DesktopAuthService.signInWithBrowser(clientId: cleanClientId);
      if (user != null) {
        _desktopEmail = user.email;
        _desktopHeaders = user.authHeaders;
        return AuthUserInfo(email: user.email, authHeaders: user.authHeaders);
      }
      return null;
    }

    // Fluxo Web (iPhone Safari, PWA, navegadores de desktop)
    if (kIsWeb) {
      // 1. Tenta login via Google Identity Services
      try {
        final googleInstance = GoogleSignIn(
          clientId: cleanClientId,
          scopes: const [
            'https://www.googleapis.com/auth/drive.file',
            'email',
          ],
        );
        final u = await googleInstance.signIn();
        if (u != null) {
          return AuthUserInfo(email: u.email, authHeaders: await u.authHeaders);
        }
      } catch (e) {
        debugPrint('GoogleSignIn no Web falhou ou popup bloqueado: $e. Abrindo navegador com fluxo OAuth...');
      }

      // 2. Se o popup não abriu ou falhou, abre o navegador padrão com o fluxo OAuth direto
      final authUrl = DesktopAuthService.buildWebAuthUrl(clientId: cleanClientId);
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      }
      return null;
    }

    // Fluxo Android / iOS compilado nativamente
    final googleInstance = _google ??
        GoogleSignIn(
          clientId: cleanClientId,
          scopes: const [
            'https://www.googleapis.com/auth/drive.file',
            'email',
          ],
        );
    final u = await googleInstance.signIn();
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
    await DesktopAuthService.signOut();
    _desktopEmail = null;
    _desktopHeaders = null;
    if (!isDesktop) {
      try {
        await _google?.signOut();
      } catch (_) {}
    }
  }

  Future<Map<String, String>> authHeaders() async {
    if (_desktopHeaders != null) return _desktopHeaders!;
    final user = DesktopAuthService.currentUser;
    if (user != null) return user.authHeaders;

    final u = _google?.currentUser;
    if (u != null) return u.authHeaders;

    throw StateError('Usuário não está conectado ao Google.');
  }
}
