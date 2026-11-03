/// Estrutura da planilha criada na conta de cada usuário.
class SheetSchema {
  SheetSchema._();

  static const title = 'Cifras App';
  static const version = '1';

  /// Nome da aba -> linhas iniciais (a primeira é o cabeçalho).
  static const Map<String, List<List<String>>> tabs = {
    'Musicas': [
      ['id', 'titulo', 'artista', 'tomOriginal', 'conteudo', 'criadoEm', 'atualizadoEm', 'excluido'],
    ],
    'Setlists': [
      ['id', 'nome', 'observacoes', 'atualizadoEm', 'excluido'],
    ],
    'ItensSetlist': [
      ['id', 'setlistId', 'musicaId', 'posicao', 'tomNaLista', 'atualizadoEm', 'excluido'],
    ],
    'Acordes': [
      ['id', 'nome', 'casas', 'atualizadoEm', 'excluido'],
    ],
    'Config': [
      ['chave', 'valor'],
      ['schemaVersion', version],
    ],
  };
}
