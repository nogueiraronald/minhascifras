/// Detecção e transposição de acordes em texto.
class ExtractedChord {
  const ExtractedChord({
    required this.prefix,
    required this.chord,
    required this.suffix,
  });

  final String prefix;
  final String chord;
  final String suffix;
}

class ChordTransposer {
  ChordTransposer._();

  static const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  static const _flats = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

  static final _chord = RegExp(r'^([A-Ga-g][#b]?)([^/\s]*)(?:/([A-Ga-g][#b]?|\d+))?$');
  static final _quality = RegExp(
    r'^(maj|min|dim|aug|sus|add|m|M|alt|omit|no|\+|-|°|º|ø|Ø|Δ|\^|\d|\(|\)|#|b)*$',
  );
  static final _hasFlat = RegExp(r'^[A-Ga-g]b|/[A-Ga-g]b');

  // Marcadores de seção e cifras que podem aparecer em linhas de acordes
  static final _marker = RegExp(
    r'^(\[.*\]|intro:?|solo:?|riff:?|refrão:?|refr[aã]o:?|ponte:?|final:?|coda:?|interl[uú]dio:?|verso:?|1[ªa]\s*parte:?|2[ªa]\s*parte:?|primeira\s+parte:?|segunda\s+parte:?|verse:?|chorus:?|bridge:?|outro:?|\|+|/+|\\+|-+|~+|\.{2,}|:|\|:|:\||%|\(?[0-9]+[xX]\)?|\(?x[0-9]+\)?|\(bis\)|\(pausa\)|\(parada\)|\(corta\)|\(segura\)|\(breque\)|\(dedilhado\)|\(batida\)|\(suave\)|\(rápido\)|\([0-9]+\s*tempos?\)|\(refrão\)|\(ponte\)|\(intro\)|n\.?c\.?)$',
    caseSensitive: false,
  );

  /// Remove caracteres invisíveis (zero-width space, BOM) e normaliza espaços.
  static String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[\u200b\u200c\u200d\ufeff]'), '')
        .replaceAll('\u00a0', ' ');
  }

  /// Verifica se a string em formato puro é um acorde musical válido.
  static bool isRawChord(String candidate) {
    if (candidate.isEmpty) return false;
    final m = _chord.firstMatch(candidate);
    if (m == null) return false;
    final quality = m.group(2) ?? '';
    return _quality.hasMatch(quality);
  }

  /// Separa qualquer pontuação inicial ou final de um token para extrair o acorde.
  /// Suporta acordes com vírgulas (G,), parênteses ((G7)), colchetes ([Am]), etc.
  static ExtractedChord? parseTokenChord(String token) {
    var t = cleanText(token).trim();
    if (t.isEmpty) return null;

    String prefix = '';
    String suffix = '';

    // Extrai delimitadores ou pontuações iniciais
    while (t.isNotEmpty &&
        (t.startsWith('[') ||
            t.startsWith('(') ||
            t.startsWith('|') ||
            t.startsWith('{') ||
            t.startsWith('"') ||
            t.startsWith("'"))) {
      prefix += t[0];
      t = t.substring(1).trim();
    }

    // Extrai pontuações finais
    while (t.isNotEmpty &&
        (t.endsWith(']') ||
            t.endsWith(')') ||
            t.endsWith('|') ||
            t.endsWith('}') ||
            t.endsWith(',') ||
            t.endsWith(';') ||
            t.endsWith('.') ||
            t.endsWith('!') ||
            t.endsWith('"') ||
            t.endsWith("'"))) {
      suffix = t[t.length - 1] + suffix;
      t = t.substring(0, t.length - 1).trim();
    }

    if (isRawChord(t)) {
      return ExtractedChord(prefix: prefix, chord: t, suffix: suffix);
    }
    return null;
  }

  /// Limpa pontuações periféricas de um token para obter o acorde puro.
  static String cleanToken(String token) {
    final parsed = parseTokenChord(token);
    if (parsed != null) return parsed.chord;
    var t = cleanText(token).trim();
    if (t.startsWith('[') && t.endsWith(']') && t.length > 2) {
      t = t.substring(1, t.length - 1).trim();
    } else if (t.startsWith('(') && t.endsWith(')') && t.length > 2) {
      t = t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  /// Retorna o acorde sem pontuações para consulta no dicionário de acordes.
  static String cleanChordForLookup(String chord) {
    final parsed = parseTokenChord(chord);
    return parsed != null ? parsed.chord : cleanToken(chord);
  }

  /// Verifica se o token é um marcador de seção ou indicação musical.
  static bool isMarker(String token) {
    final t = cleanText(token).trim();
    return _marker.hasMatch(t);
  }

  /// Verifica se o token representa um acorde válido (ex: C, Am7, G#m7, B2, D/F#, G,, [G]).
  static bool isChord(String token) {
    return parseTokenChord(token) != null;
  }

  /// Identifica se uma linha é uma linha de acordes para transposição.
  /// Aceita linhas com acordes isolados, separados por vírgulas, barras, traços, marcadores, etc.
  static bool isChordLine(String line) {
    final clean = cleanText(line).trim();
    if (clean.isEmpty) return false;

    // Normaliza acordes colados por vírgula sem espaço (ex: G,G7 -> G, G7)
    final normalized = clean.replaceAllMapped(
      RegExp(r'([A-Ga-g][#b]?[^,\s]*),([A-Ga-g])'),
      (m) => '${m.group(1)}, ${m.group(2)}',
    );

    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return false;

    final chords = tokens.where(isChord).toList();
    if (chords.isEmpty) return false;

    // Filtra tokens que não são marcadores estruturais ([Intro], |, (2x), etc.)
    final nonMarkers = tokens.where((t) => !isMarker(t)).toList();
    if (nonMarkers.isEmpty) return false;

    // Todos os elementos não-marcadores devem ser acordes válidos
    return nonMarkers.every(isChord);
  }

  /// Transpõe um acorde pelo número de semitons especificado, preservando pontuações periféricas.
  static String transposeChord(String chord, int steps, {bool? useFlats}) {
    if (steps == 0) return chord;
    final parsed = parseTokenChord(chord);
    if (parsed == null) return chord;

    final inner = parsed.chord;
    final m = _chord.firstMatch(inner);
    if (m == null) return chord;

    final flats = useFlats ?? _hasFlat.hasMatch(inner);
    final rawRoot = m.group(1)!;
    final root = _shift(rawRoot, steps, flats);
    final quality = m.group(2) ?? '';
    final bass = m.group(3);

    String transposedBass = '';
    if (bass != null && bass.isNotEmpty) {
      if (RegExp(r'^[A-Ga-g][#b]?$').hasMatch(bass)) {
        transposedBass = '/${_shift(bass, steps, flats)}';
      } else {
        transposedBass = '/$bass';
      }
    }

    final transposed = '$root$quality$transposedBass';
    return '${parsed.prefix}$transposed${parsed.suffix}';
  }

  /// Transpõe todas as linhas de acordes de um texto (incluindo linhas de Tom: X).
  static String transposeContent(String content, int steps) {
    if (steps == 0) return cleanText(content);
    return cleanText(content)
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.toLowerCase().startsWith('tom:') || trimmed.toLowerCase().startsWith('tom :')) {
            final colonIdx = line.indexOf(':');
            final prefix = line.substring(0, colonIdx + 1);
            final rest = line.substring(colonIdx + 1);
            final m = RegExp(r'\S+').firstMatch(rest);
            if (m != null) {
              final raw = m.group(0)!;
              final parsed = parseTokenChord(raw);
              if (parsed != null) {
                final transposed = transposeChord(raw, steps);
                final replaced = rest.replaceFirst(raw, transposed);
                return '$prefix$replaced';
              }
            }
          }
          if (!isChordLine(line)) return line;
          return line.replaceAllMapped(RegExp(r'\S+'), (m) {
            final token = m.group(0)!;
            return isChord(token) ? transposeChord(token, steps) : token;
          });
        })
        .join('\n');
  }

  /// Mesmo acorde com o outro nome (C# <-> Db).
  static String enharmonic(String chord) =>
      transposeChord(chord, 0, useFlats: !_hasFlat.hasMatch(chord));

  /// Detecta o tom da música (por "Tom: X" ou primeiro acorde da cifra).
  static String? detectKey(String content) {
    final clean = cleanText(content);
    final lines = clean.replaceAll('\r\n', '\n').split('\n');
    for (final raw in lines) {
      final t = raw.trim();
      if (t.toLowerCase().startsWith('tom:') || t.toLowerCase().startsWith('tom :')) {
        final parts = t.split(':');
        if (parts.length > 1) {
          final candidate = parts[1].trim().split(RegExp(r'\s+')).first;
          if (isChord(candidate)) return cleanToken(candidate);
        }
      }
    }
    for (final raw in lines) {
      final t = raw.trim();
      if (isChordLine(t)) {
        for (final token in t.split(RegExp(r'\s+'))) {
          if (isChord(token)) return cleanToken(token);
        }
      }
    }
    return null;
  }

  static String _shift(String rawNote, int steps, bool flats) {
    if (rawNote.isEmpty) return rawNote;
    final note = rawNote[0].toUpperCase() + (rawNote.length > 1 ? rawNote.substring(1) : '');
    var i = _sharps.indexOf(note);
    if (i < 0) i = _flats.indexOf(note);
    if (i < 0) return rawNote;
    return (flats ? _flats : _sharps)[((i + steps) % 12 + 12) % 12];
  }
}
