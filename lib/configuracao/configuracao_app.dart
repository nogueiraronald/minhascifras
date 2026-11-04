/// Configurações centrais do aplicativo MinhasCifras.
class AppConfig {
  AppConfig._();

  /// Nome oficial do aplicativo.
  static const String appName = 'MinhasCifras';

  /// URL base do projeto no Supabase
  static const String supabaseUrl = 'https://ydwyokhftlauuzfrbjut.supabase.co';

  /// Chave pública anônima (anon key) do Supabase para leitura e gravação
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlkd3lva2hmdGxhdXV6ZnJianV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM4ODY1ODIsImV4cCI6MjA2OTQ2MjU4Mn0.tqX679lih7HTNvtX57CgIDbAgFymXOGcC03O82Pjy_8';

  /// Endpoint da Edge Function no Supabase para importar cifras por link
  static const String obterCifrasUrl =
      'https://ydwyokhftlauuzfrbjut.supabase.co/functions/v1/obter_cifras';
}
