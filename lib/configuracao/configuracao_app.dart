/// Configurações centrais do aplicativo MinhasCifras.
class AppConfig {
  AppConfig._();

  /// Nome oficial do aplicativo.
  static const String appName = 'MinhasCifras';

  /// Google OAuth 2.0 Client ID pré-configurado para Desktop.
  /// Embutido diretamente no aplicativo: o usuário NÃO precisa criar nem configurar nada.
  /// Ao clicar em "Entrar com o Google", o navegador abre diretamente na tela de e-mail e senha.
  static const String googleClientId =
      '202264815644.apps.googleusercontent.com';

  /// Google OAuth 2.0 Client Secret pareado com o Client ID acima.
  static const String googleClientSecret =
      'X4Z3ca8xfWDb1Voo-F9a7ZxJ';

  /// Endpoint da Edge Function no Supabase para importar cifras por link
  static const String obterCifrasUrl =
      'https://ydwyokhftlauuzfrbjut.supabase.co/functions/v1/obter_cifras';
}
