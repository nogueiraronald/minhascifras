import 'package:google_sign_in/google_sign_in.dart';

/// Login do Google feito pelo próprio usuário (tela do Google, sem senha no app).
/// Escopo mínimo: o app só enxerga arquivos que ele mesmo criou.
class GoogleAuthService {
  GoogleAuthService()
      : _google = GoogleSignIn(
          scopes: const ['https://www.googleapis.com/auth/drive.file'],
        );

  final GoogleSignIn _google;

  GoogleSignInAccount? get user => _google.currentUser;

  Future<GoogleSignInAccount?> signInSilently() => _google.signInSilently();

  Future<GoogleSignInAccount?> signIn() => _google.signIn();

  Future<void> signOut() => _google.signOut();

  /// Cabeçalhos com o token do usuário (Authorization: Bearer ...).
  Future<Map<String, String>> authHeaders() async {
    final u = _google.currentUser;
    if (u == null) throw StateError('Usuário não está logado.');
    return u.authHeaders;
  }
}
