import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DesktopAuthUser {
  DesktopAuthUser({
    required this.email,
    required this.accessToken,
    this.refreshToken,
    this.name,
  });

  final String email;
  final String accessToken;
  final String? refreshToken;
  final String? name;

  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer $accessToken',
      };
}

/// Autenticação OAuth 2.0 padrão (RFC 8252) com loopback local e PKCE para Desktop (macOS, Windows, Linux).
class DesktopAuthService {
  DesktopAuthService._();

  static const _kAccessToken = 'desktop_oauth_access_token';
  static const _kRefreshToken = 'desktop_oauth_refresh_token';
  static const _kEmail = 'desktop_oauth_email';
  static const _kClientId = 'desktop_oauth_client_id';

  static DesktopAuthUser? _currentUser;
  static DesktopAuthUser? get currentUser => _currentUser;

  /// Retoma sessão anterior salva
  static Future<DesktopAuthUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessToken);
    final email = prefs.getString(_kEmail);
    final refresh = prefs.getString(_kRefreshToken);

    if (token == null || email == null) return null;

    // Se temos refresh token e client ID, podemos atualizar o access token se necessário
    final clientId = prefs.getString(_kClientId);
    if (refresh != null && clientId != null && clientId.isNotEmpty) {
      try {
        final refreshed = await _refreshToken(clientId, refresh);
        if (refreshed != null) {
          _currentUser = refreshed;
          return _currentUser;
        }
      } catch (_) {}
    }

    _currentUser = DesktopAuthUser(email: email, accessToken: token, refreshToken: refresh);
    return _currentUser;
  }

  /// Retorna o Client ID configurado ou vazio
  static Future<String> getSavedClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kClientId) ?? '';
  }

  static Future<void> saveClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClientId, clientId.trim());
  }

  /// Inicia o fluxo de login via navegador com servidor local loopback
  static Future<DesktopAuthUser?> signInWithBrowser({required String clientId}) async {
    final cleanClientId = clientId.trim();
    if (cleanClientId.isEmpty) {
      throw ArgumentError('O Google Client ID não pode estar vazio.');
    }

    // Salva o client ID para renovações futuras
    await saveClientId(cleanClientId);

    // Gera PKCE code_verifier e code_challenge (RFC 7636)
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);

    // Inicia servidor HTTP local em porta efêmera no localhost
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': cleanClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'https://www.googleapis.com/auth/drive.file email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
    });

    // Abre o navegador padrão do sistema
    if (Platform.isMacOS) {
      await Process.run('open', [authUrl.toString()]);
    } else if (Platform.isWindows) {
      await Process.run('start', [authUrl.toString()], runInShell: true);
    } else {
      await Process.run('xdg-open', [authUrl.toString()]);
    }

    String? authCode;
    String? error;

    try {
      // Aguarda a resposta do Google no servidor local (timeout de 2 minutos)
      await for (final request in server.timeout(const Duration(minutes: 2))) {
        final params = request.uri.queryParameters;
        authCode = params['code'];
        error = params['error'];

        request.response.headers.contentType = ContentType.html;
        if (authCode != null) {
          request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Login Concluído</title>
  <style>
    body { font-family: -apple-system, sans-serif; text-align: center; padding: 40px; background: #f8f9fa; }
    .card { background: white; padding: 30px; border-radius: 12px; max-width: 450px; margin: auto; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
    h2 { color: #1a73e8; }
    p { color: #5f6368; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Login concluído com sucesso!</h2>
    <p>Sua conta Google foi autenticada. Você já pode fechar esta aba e voltar ao aplicativo Cifras.</p>
  </div>
</body>
</html>
''');
        } else {
          request.response.write('''
<!DOCTYPE html>
<html>
<body>
  <h2>Falha na autenticação: ${error ?? 'cancelado pelo usuário'}</h2>
  <p>Você pode fechar esta janela.</p>
</body>
</html>
''');
        }
        await request.response.close();
        break;
      }
    } finally {
      await server.close(force: true);
    }

    if (authCode == null) {
      if (error != null) throw Exception('Google recusou o login: $error');
      throw Exception('Tempo limite para login expirado.');
    }

    // Troca o código pelo access_token
    final tokenUri = Uri.parse('https://oauth2.googleapis.com/token');
    final tokenRes = await http.post(
      tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': cleanClientId,
        'code': authCode,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );

    if (tokenRes.statusCode != 200) {
      throw Exception('Falha ao obter token do Google (${tokenRes.statusCode}): ${tokenRes.body}');
    }

    final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;
    final refreshToken = tokenData['refresh_token'] as String?;

    // Obtém dados do usuário (email)
    final userInfoRes = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    String userEmail = 'usuario@gmail.com';
    String? userName;
    if (userInfoRes.statusCode == 200) {
      final info = jsonDecode(userInfoRes.body) as Map<String, dynamic>;
      userEmail = (info['email'] as String?) ?? userEmail;
      userName = info['name'] as String?;
    }

    // Persiste nos SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kEmail, userEmail);
    if (refreshToken != null) {
      await prefs.setString(_kRefreshToken, refreshToken);
    }

    _currentUser = DesktopAuthUser(
      email: userEmail,
      accessToken: accessToken,
      refreshToken: refreshToken,
      name: userName,
    );

    return _currentUser;
  }

  /// Permite autenticar diretamente com um token informado
  static Future<DesktopAuthUser> signInWithDirectToken({
    required String accessToken,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kEmail, email);

    _currentUser = DesktopAuthUser(email: email, accessToken: accessToken);
    return _currentUser!;
  }

  static Future<DesktopAuthUser?> _refreshToken(String clientId, String refreshToken) async {
    final tokenUri = Uri.parse('https://oauth2.googleapis.com/token');
    final res = await http.post(
      tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final newToken = data['access_token'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, newToken);

    final email = prefs.getString(_kEmail) ?? 'usuario@gmail.com';
    return DesktopAuthUser(email: email, accessToken: newToken, refreshToken: refreshToken);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kEmail);
    _currentUser = null;
  }

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
