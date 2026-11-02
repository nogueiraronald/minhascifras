import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/google_auth_service.dart';
import '../services/sheets_service.dart';

enum AccountStatus { signedOut, working, ready, error }

/// Estado da conta Google e da planilha do usuário.
class AccountController extends ChangeNotifier {
  AccountController._(this._auth, this._sheets, this._prefs);

  final GoogleAuthService _auth;
  final SheetsService _sheets;
  final SharedPreferences _prefs;

  AccountStatus status = AccountStatus.signedOut;
  String? email;
  String? spreadsheetId;
  String? error;

  SheetsService get sheets => _sheets;
  GoogleAuthService get auth => _auth;

  static Future<AccountController> open() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = GoogleAuthService();
    return AccountController._(auth, SheetsService(auth), prefs);
  }

  /// Retoma a sessão anterior sem abrir tela de login.
  Future<void> restore() async {
    try {
      final u = await _auth.signInSilently();
      if (u != null) await _setup(u);
    } catch (_) {
      // Sem rede ou sem configuração: o app segue funcionando localmente.
    }
  }

  Future<void> signIn({String? desktopClientId}) async {
    _update(AccountStatus.working);
    try {
      final u = await _auth.signIn(desktopClientId: desktopClientId);
      if (u == null) {
        _update(AccountStatus.signedOut);
        return;
      }
      await _setup(u);
    } catch (e) {
      error = '$e';
      _update(AccountStatus.error);
      rethrow;
    }
  }

  Future<void> signInDirectToken({
    required String accessToken,
    required String email,
  }) async {
    _update(AccountStatus.working);
    try {
      final u = await _auth.signInDirectToken(accessToken: accessToken, email: email);
      await _setup(u);
    } catch (e) {
      error = '$e';
      _update(AccountStatus.error);
      rethrow;
    }
  }

  Future<void> retry() async {
    await restore();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    email = null;
    spreadsheetId = null;
    error = null;
    _update(AccountStatus.signedOut);
  }

  Future<void> _setup(AuthUserInfo u) async {
    email = u.email;
    _update(AccountStatus.working);
    try {
      final key = 'sheet_id_${u.email}';
      var id = _prefs.getString(key);
      id ??= await _sheets.ensureSpreadsheet();
      await _prefs.setString(key, id);
      spreadsheetId = id;
      error = null;
      _update(AccountStatus.ready);
    } catch (e) {
      error = '$e';
      _update(AccountStatus.error);
    }
  }

  void _update(AccountStatus s) {
    status = s;
    notifyListeners();
  }
}
