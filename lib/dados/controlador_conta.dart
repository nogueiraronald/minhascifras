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

  static const String _kSyncCode = 'supabase_sync_code';
  static const String _kSyncPasswordHash = 'supabase_sync_password_hash';

  AccountStatus status = AccountStatus.ready;
  String? syncCode;
  String? passwordHash;
  String? pendingSyncCode;
  String? pendingPasswordHash;
  String? error;

  bool get isPasswordProtected =>
      passwordHash != null && passwordHash!.isNotEmpty;

  bool get isLocked => status == AccountStatus.locked;
  bool get hasPendingSync =>
      pendingSyncCode != null && pendingSyncCode!.isNotEmpty;


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

  /// Mantido para compatibilidade com a UI
  String? get email => syncCode != null ? 'Código: $syncCode' : null;
  String? get spreadsheetId => syncCode;

  static Future<AccountController> open(
      {SupabaseSyncService? supabaseSync}) async {
    final prefs = await SharedPreferences.getInstance();
    final controller =
        AccountController._(prefs, supabaseSync: supabaseSync);
    await controller.restore();
    return controller;
  }

  /// Carrega o código existente, detecta link via QR Code (?sync=...) ou gera um código único na primeira abertura
  Future<void> restore() async {
    try {
      passwordHash = _prefs.getString(_kSyncPasswordHash);

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

  /// Desconecta do repertório atual e gera um novo código vazio do zero
  Future<String> resetToNewAccount() async {
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
