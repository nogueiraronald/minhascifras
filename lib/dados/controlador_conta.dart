import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../servicos/servico_supabase_sync.dart';

enum AccountStatus { signedOut, working, ready, error, locked }

/// Controlador do código de sincronização do Supabase para backup sem conta/senha.
class AccountController extends ChangeNotifier {
  AccountController._(this._prefs, {SupabaseSyncService? supabaseSync})
      : _supabaseSync = supabaseSync ?? SupabaseSyncService();

  final SharedPreferences _prefs;
  final SupabaseSyncService _supabaseSync;

  static const String _kUserEmail = 'user_account_email';
  static const String _kUserNickname = 'user_account_nickname';
  static const String _kSyncCode = 'supabase_sync_code';
  static const String _kSyncPasswordHash = 'supabase_sync_password_hash';

  AccountStatus status = AccountStatus.ready;
  String? _userEmail;
  String? _userNickname;
  String? syncCode;
  String? passwordHash;
  String? pendingSyncCode;
  String? pendingPasswordHash;
  String? error;

  bool get isLoggedIn => _userEmail != null && _userEmail!.trim().isNotEmpty;
  String? get userEmail => _userEmail;
  String? get userNickname => _userNickname;
  bool get hasNickname =>
      _userNickname != null && _userNickname!.trim().isNotEmpty;

  /// Para postar cifras na comunidade, o usuário precisa ter e-mail, senha e nickname cadastrados.
  bool get canPostToCommunity =>
      isLoggedIn && isPasswordProtected && hasNickname;

  bool get isPasswordProtected =>
      passwordHash != null && passwordHash!.isNotEmpty;

  bool get isLocked => status == AccountStatus.locked;
  bool get hasPendingSync =>
      pendingSyncCode != null && pendingSyncCode!.isNotEmpty;

  /// Converte um e-mail de forma determinística e segura para o código de sincronização do Supabase
  static String emailToSyncCode(String email) {
    final clean = email.trim().toLowerCase();
    final digest = sha256.convert(utf8.encode(clean)).toString();
    return 'USR_${digest.substring(0, 24).toUpperCase()}';
  }

  /// Retorna a URL completa para pareamento instantâneo via QR Code
  String get syncUrl {
    final code = syncCode ?? '';
    if (kIsWeb) {
      final origin = Uri.base.origin;
      var path = Uri.base.path;
      if (path.endsWith('index.html')) {
        path = path.substring(0, path.length - 'index.html'.length);
      }
      if (!path.endsWith('/')) {
        path = '$path/';
      }
      return '$origin$path?sync=$code';
    }
    return 'https://nogueiraronald.github.io/minhascifras-web/?sync=$code';
  }

  /// Extrai o identificador limpo a partir de texto digitado, copiado ou link completo com ?sync=...
  static String extractCode(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';

    if (text.contains('sync=')) {
      final uri = Uri.tryParse(text);
      if (uri != null && uri.queryParameters.containsKey('sync')) {
        final val = uri.queryParameters['sync']?.trim().toUpperCase();
        if (val != null && val.isNotEmpty) return val;
      }
      final match = RegExp(r'[?&]sync=([a-zA-Z0-9_-]+)').firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toUpperCase();
      }
    }

    return text.toUpperCase();
  }

  /// Retorna o e-mail ou identificador amigável da conta
  String? get email => _userEmail ?? (syncCode != null ? 'Código: $syncCode' : null);
  String? get spreadsheetId => syncCode;

  static Future<AccountController> open(
      {SupabaseSyncService? supabaseSync}) async {
    final prefs = await SharedPreferences.getInstance();
    final controller =
        AccountController._(prefs, supabaseSync: supabaseSync);
    await controller.restore();
    return controller;
  }

  /// Carrega a conta salva (e-mail ou código existente)
  Future<void> restore() async {
    try {
      _userEmail = _prefs.getString(_kUserEmail);
      _userNickname = _prefs.getString(_kUserNickname);
      passwordHash = _prefs.getString(_kSyncPasswordHash);

      if (_userEmail != null && _userEmail!.trim().isNotEmpty) {
        syncCode = emailToSyncCode(_userEmail!);
        await _prefs.setString(_kSyncCode, syncCode!);
        status = AccountStatus.ready;
        error = null;
        notifyListeners();
        return;
      }

      // 1. Se foi aberto via leitura de QR Code (?sync=MC-XXXXXX)
      if (kIsWeb && Uri.base.queryParameters.containsKey('sync')) {
        final rawSync = Uri.base.queryParameters['sync'];
        if (rawSync != null) {
          final querySync = extractCode(rawSync);
          if (querySync.isNotEmpty) {
            final remoteHash = await checkRemotePassword(querySync);
            final savedCode = _prefs.getString(_kSyncCode);
            final savedHash = _prefs.getString(_kSyncPasswordHash);

            if (remoteHash != null && remoteHash.isNotEmpty) {
              if (savedCode == querySync && savedHash == remoteHash) {
                // Já autenticado anteriormente com sucesso neste aparelho
                syncCode = querySync;
                passwordHash = savedHash;
                status = AccountStatus.ready;
                error = null;
                notifyListeners();
                return;
              } else {
                // Exige validação de senha antes de sincronizar ou baixar músicas!
                pendingSyncCode = querySync;
                pendingPasswordHash = remoteHash;
                status = AccountStatus.locked;
                error = 'Repertório protegido por senha.';
                notifyListeners();
                return;
              }
            } else {
              // Sem senha configurada na nuvem
              await _prefs.setString(_kSyncCode, querySync);
              syncCode = querySync;
              passwordHash = null;
              status = AccountStatus.ready;
              error = null;
              notifyListeners();
              return;
            }
          }
        }
      }

      var saved = _prefs.getString(_kSyncCode);
      if (saved == null || saved.trim().isEmpty) {
        saved = _generateCode();
        await _prefs.setString(_kSyncCode, saved);
      }
      syncCode = saved;
      status = AccountStatus.ready;
      error = null;
    } catch (e) {
      error = '$e';
      status = AccountStatus.error;
    }
    notifyListeners();
  }

  /// Desbloqueia o repertório pendente com a senha correta digitada pelo usuário
  Future<bool> unlockPendingSync(String password) async {
    if (pendingSyncCode == null || pendingPasswordHash == null) return false;
    final clean = password.trim();
    final typedHash = sha256.convert(utf8.encode(clean)).toString();
    if (typedHash != pendingPasswordHash) {
      return false;
    }

    final code = pendingSyncCode!;
    await _prefs.setString(_kSyncCode, code);
    await _prefs.setString(_kSyncPasswordHash, typedHash);
    syncCode = code;
    passwordHash = typedHash;
    pendingSyncCode = null;
    pendingPasswordHash = null;
    status = AccountStatus.ready;
    error = null;
    notifyListeners();
    return true;
  }

  /// Cancela o pareamento pendente e mantém o código local
  void cancelPendingSync() {
    pendingSyncCode = null;
    pendingPasswordHash = null;
    var saved = _prefs.getString(_kSyncCode);
    if (saved == null || saved.trim().isEmpty) {
      saved = _generateCode();
      _prefs.setString(_kSyncCode, saved);
    }
    syncCode = saved;
    passwordHash = _prefs.getString(_kSyncPasswordHash);
    status = AccountStatus.ready;
    error = null;
    notifyListeners();
  }

  /// Trava a conta localmente caso a nuvem detecte exigência de senha
  void lockWithRemoteHash(String remoteHash) {
    if (syncCode != null && syncCode!.isNotEmpty) {
      pendingSyncCode = syncCode;
      pendingPasswordHash = remoteHash;
      status = AccountStatus.locked;
      error = 'Repertório protegido por senha.';
      notifyListeners();
    }
  }

  /// Verifica se um código remoto na nuvem possui senha de proteção configurada
  Future<String?> checkRemotePassword(String code) async {
    return _supabaseSync.checkPasswordHash(code);
  }

  /// Configura uma senha para proteger o repertório na nuvem contra tentativas de adivinhação
  Future<void> setPassword(String password) async {
    final clean = password.trim();
    if (clean.isEmpty) {
      await removePassword();
      return;
    }

    final hash = sha256.convert(utf8.encode(clean)).toString();
    await _prefs.setString(_kSyncPasswordHash, hash);
    passwordHash = hash;
    notifyListeners();
  }

  /// Remove a senha de proteção do repertório
  Future<void> removePassword() async {
    await _prefs.remove(_kSyncPasswordHash);
    passwordHash = null;
    notifyListeners();
  }

  /// Conecta a um repertório existente através de um código fornecido pelo usuário
  Future<void> connectToSyncCode(String newCode,
      {String? passwordHash}) async {
    final clean = extractCode(newCode);
    if (clean.isEmpty) {
      throw StateError('Por favor, informe ou cole um código válido.');
    }

    _update(AccountStatus.working);
    try {
      await _prefs.setString(_kSyncCode, clean);
      syncCode = clean;

      if (passwordHash != null && passwordHash.isNotEmpty) {
        await _prefs.setString(_kSyncPasswordHash, passwordHash);
        this.passwordHash = passwordHash;
      } else {
        await _prefs.remove(_kSyncPasswordHash);
        this.passwordHash = null;
      }

      error = null;
      _update(AccountStatus.ready);
    } catch (e) {
      error = '$e';
      _update(AccountStatus.error);
      rethrow;
    }
  }

  /// Define ou atualiza o nickname do usuário para compartilhamento na Comunidade
  Future<void> setNickname(String nickname) async {
    final clean = nickname.trim().replaceFirst(RegExp(r'^@+'), '');
    if (clean.isEmpty) {
      await _prefs.remove(_kUserNickname);
      _userNickname = null;
    } else {
      final email = _userEmail ?? '';
      final code = syncCode ?? (email.isNotEmpty ? emailToSyncCode(email) : '');
      final taken = await _supabaseSync.isNicknameTakenByAnotherUser(
        nickname: clean,
        ownSyncCode: code,
        ownEmail: email,
      );
      if (taken) {
        throw FormatException(
          'O nickname "@$clean" já está em uso por outro e-mail. Por favor, escolha outro nickname.',
        );
      }
      await _prefs.setString(_kUserNickname, clean);
      _userNickname = clean;
    }
    notifyListeners();
  }

  /// Autentica ou vincula com E-mail e Senha no Supabase.
  /// Se o e-mail já existir na nuvem, valida a senha e retorna o total de músicas remotas.
  /// Se for novo, vincula e define a senha.
  Future<int> loginWithEmailAndPassword({
    required String emailInput,
    required String passwordInput,
    String? nicknameInput,
    Future<void> Function()? onSync,
  }) async {
    final cleanEmail = emailInput.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw const FormatException('Por favor, informe um endereço de e-mail válido.');
    }
    final cleanPassword = passwordInput.trim();
    if (cleanPassword.isEmpty) {
      throw const FormatException('Por favor, digite uma senha de acesso.');
    }

    _update(AccountStatus.working);

    try {
      final code = emailToSyncCode(cleanEmail);
      final typedHash = sha256.convert(utf8.encode(cleanPassword)).toString();

      final cleanNick = nicknameInput?.trim().replaceFirst(RegExp(r'^@+'), '');
      if (cleanNick != null && cleanNick.isNotEmpty) {
        final taken = await _supabaseSync.isNicknameTakenByAnotherUser(
          nickname: cleanNick,
          ownSyncCode: code,
          ownEmail: cleanEmail,
        );
        if (taken) {
          throw FormatException(
            'O nickname "@$cleanNick" já está em uso por outro e-mail. Por favor, escolha outro nickname.',
          );
        }
      }

      // Consulta se já existe esse repertório na nuvem
      final remote = await _supabaseSync.readAll(code);

      if (remote.songs.isNotEmpty || (remote.passwordHash != null && remote.passwordHash!.isNotEmpty)) {
        if (remote.passwordHash != null && remote.passwordHash!.isNotEmpty) {
          if (typedHash != remote.passwordHash) {
            throw Exception('Senha incorreta para este e-mail. Por favor, verifique e tente novamente.');
          }
        }
      }

      await _prefs.setString(_kUserEmail, cleanEmail);
      await _prefs.setString(_kSyncCode, code);
      await _prefs.setString(_kSyncPasswordHash, typedHash);

      if (cleanNick != null && cleanNick.isNotEmpty) {
        await _prefs.setString(_kUserNickname, cleanNick);
        _userNickname = cleanNick;
      } else if (remote.nickname != null && remote.nickname!.trim().isNotEmpty) {
        final remoteNick = remote.nickname!.trim();
        await _prefs.setString(_kUserNickname, remoteNick);
        _userNickname = remoteNick;
      }

      _userEmail = cleanEmail;
      syncCode = code;
      passwordHash = typedHash;
      pendingSyncCode = null;
      pendingPasswordHash = null;
      error = null;
      _update(AccountStatus.ready);

      if (onSync != null) {
        await onSync();
      }

      return remote.songs.length;
    } catch (e) {
      error = '$e'.replaceFirst(RegExp(r'^(Exception|FormatException|StateError):\s*'), '');
      _update(AccountStatus.error);
      rethrow;
    }
  }

  /// Desconecta o usuário deste aparelho, removendo o e-mail e credenciais salvas
  Future<void> signOutUser({
    Future<void> Function()? onClearLocalData,
  }) async {
    _update(AccountStatus.working);
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserNickname);
    await _prefs.remove(_kSyncCode);
    await _prefs.remove(_kSyncPasswordHash);

    _userEmail = null;
    _userNickname = null;
    passwordHash = null;
    pendingSyncCode = null;
    pendingPasswordHash = null;

    final newCode = _generateCode();
    await _prefs.setString(_kSyncCode, newCode);
    syncCode = newCode;
    error = null;

    if (onClearLocalData != null) {
      await onClearLocalData();
    }

    _update(AccountStatus.ready);
  }

  /// Desconecta do repertório atual e gera um novo código vazio do zero
  Future<String> resetToNewAccount() async {
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserNickname);
    _userEmail = null;
    _userNickname = null;
    final newCode = _generateCode();
    await _prefs.setString(_kSyncCode, newCode);
    await _prefs.remove(_kSyncPasswordHash);
    syncCode = newCode;
    passwordHash = null;
    error = null;
    _update(AccountStatus.ready);
    return newCode;
  }

  /// Gera um novo código para começar um novo repertório do zero
  Future<String> generateNewSyncCode() async {
    return resetToNewAccount();
  }

  /// Compatibilidade com chamadas signIn existentes
  Future<void> signIn({String? desktopClientId}) async {
    await restore();
  }

  /// Compatibilidade com chamadas signOut existentes
  Future<void> signOut() async {
    await resetToNewAccount();
  }

  Future<void> retry() async {
    await restore();
  }

  void _update(AccountStatus s) {
    status = s;
    notifyListeners();
  }

  static String _generateCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    final buffer = StringBuffer('MC-');
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}
