/// Configurações centrais do aplicativo MinhasCifras.
class AppConfig {
  AppConfig._();

  /// Nome oficial do aplicativo.
  static const String appName = 'MinhasCifras';

  /// Google OAuth 2.0 Client ID padrão para Desktop (macOS, Windows, Linux).
  static const String googleClientId =
      '939106707928-204229furumo56sqd7lqck6aojjagejl.apps.googleusercontent.com';

  /// Google OAuth 2.0 Client ID específico para Web / PWA (Aplicativo da Web).
  static const String googleWebClientId =
      '939106707928-204229furumo56sqd7lqck6aojjagejl.apps.googleusercontent.com';

  /// Retorna o Client ID padrão para a plataforma
  static String get effectiveClientId => googleClientId;

  /// Google OAuth 2.0 Client Secret pareado com o Client ID acima.
  static const String googleClientSecret =
      'X4Z3ca8xfWDb1Voo-F9a7ZxJ';

  /// Endpoint da Edge Function no Supabase para importar cifras por link
  static const String obterCifrasUrl =
      'https://ydwyokhftlauuzfrbjut.supabase.co/functions/v1/obter_cifras';
}
