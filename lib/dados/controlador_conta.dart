import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountStatus { signedOut, working, ready, error }

/// Controlador do código de sincronização do Supabase para backup sem conta/senha.
class AccountController extends ChangeNotifier {
  AccountController._(this._prefs);

  final SharedPreferences _prefs;
  static const String _kSyncCode = 'supabase_sync_code';

  AccountStatus status = AccountStatus.ready;
  String? syncCode;
  String? error;

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

  static Future<AccountController> open() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = AccountController._(prefs);
    await controller.restore();
    return controller;
  }

  /// Carrega o código existente, detecta link via QR Code (?sync=...) ou gera um código único na primeira abertura
  Future<void> restore() async {
    try {
      // 1. Se foi aberto via leitura de QR Code (?sync=MC-XXXXXX)
      if (kIsWeb && Uri.base.queryParameters.containsKey('sync')) {
        final rawSync = Uri.base.queryParameters['sync'];
        if (rawSync != null) {
          final querySync = extractCode(rawSync);
          if (querySync.isNotEmpty) {
            await _prefs.setString(_kSyncCode, querySync);
            syncCode = querySync;
            status = AccountStatus.ready;
            error = null;
            notifyListeners();
            return;
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

  /// Conecta a um repertório existente através de um código fornecido pelo usuário
  Future<void> connectToSyncCode(String newCode) async {
    final clean = extractCode(newCode);
    if (clean.isEmpty) {
      throw StateError('Por favor, informe ou cole um código válido.');
    }

    _update(AccountStatus.working);
    try {
      await _prefs.setString(_kSyncCode, clean);
      syncCode = clean;
      error = null;
      _update(AccountStatus.ready);
    } catch (e) {
      error = '$e';
      _update(AccountStatus.error);
      rethrow;
    }
  }

  /// Gera um novo código para começar um novo repertório do zero
  Future<String> generateNewSyncCode() async {
    final newCode = _generateCode();
    await _prefs.setString(_kSyncCode, newCode);
    syncCode = newCode;
    error = null;
    _update(AccountStatus.ready);
    return newCode;
  }

  /// Compatibilidade com chamadas signIn existentes
  Future<void> signIn({String? desktopClientId}) async {
    await restore();
  }

  /// Compatibilidade com chamadas signOut existentes
  Future<void> signOut() async {
    await generateNewSyncCode();
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
