import 'package:flutter/material.dart';

import '../servicos/transpositor_acordes.dart';

/// Uma nota individual a ser desenhada na pauta musical.
class ScoreNote {
  const ScoreNote({
    required this.name,
    required this.step,
    this.accidental,
    this.octave = 4,
  });

  /// Nome da nota (ex: 'C', 'D#', 'Bb')
  final String name;

  /// Posição vertical relativa ao Dó central C4 (C4 = 0, D4 = 1, E4 = 2, ..., A5 = 12)
  /// E4 (primeira linha inferior) = 2
  /// G4 (segunda linha) = 4
  /// B4 (terceira linha) = 6
  /// D5 (quarta linha) = 8
  /// F5 (quinta linha superior) = 10
  final int step;

  /// '#' ou 'b' se houver alteração
  final String? accidental;

  final int octave;
}

/// Um compasso na partitura com seu acorde e letra opcional.
class ScoreMeasure {
  const ScoreMeasure({
    required this.chord,
    required this.rawChord,
    required this.notes,
    this.lyrics = '',
  });

  final String chord;
  final String rawChord;
  final List<ScoreNote> notes;
  final String lyrics;
}

/// Um sistema (linha horizontal de pauta musical) que agrupa compassos.
class ScoreSystemItem {
  final List<ScoreMeasure> measures;
  final String? sectionMarker;
  final String? standaloneLyric;
  final bool isStartOfSong;

  const ScoreSystemItem.measures({
    required this.measures,
    this.sectionMarker,
    this.isStartOfSong = false,
  }) : standaloneLyric = null;

  const ScoreSystemItem.section(this.sectionMarker)
      : measures = const [],
        standaloneLyric = null,
        isStartOfSong = false;

  const ScoreSystemItem.lyric(this.standaloneLyric)
      : measures = const [],
        sectionMarker = null,
        isStartOfSong = false;
}

/// Visualizador em formato de Partitura (Lead Sheet / Pauta Musical) gerada automaticamente
/// a partir da leitura e análise harmônica da cifra e letra.
class ScoreSheetView extends StatelessWidget {
  const ScoreSheetView({
    super.key,
    required this.content,
    required this.transpose,
    required this.fontSize,
    required this.onChordTap,
    this.controller,
  });

  final String content;
  final int transpose;
  final double fontSize;
  final void Function(String chord) onChordTap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Escala geral proporcional ao fontSize
    final scale = (fontSize / 16.0).clamp(0.75, 1.7);
    final systems = _parseContentToScoreSystems(content, transpose);

    if (systems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nenhuma cifra identificada para gerar a partitura.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: fontSize),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        24 * scale,
        20 * scale,
        260 * scale,
      ),
      itemCount: systems.length,
      itemBuilder: (context, index) {
        final item = systems[index];

        // 1. Marcador de Seção ([Intro], [Refrão], [Ponte], etc.)
        if (item.sectionMarker != null && item.measures.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 18 * scale, bottom: 8 * scale),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 4 * scale),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note, size: 14 * scale, color: scheme.primary),
                      SizedBox(width: 6 * scale),
                      Text(
                        item.sectionMarker!,
                        style: TextStyle(
                          fontSize: (fontSize * 0.85).clamp(11.0, 18.0),
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // 2. Linha de letra pura sem acordes
        if (item.standaloneLyric != null) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 8 * scale),
            child: Text(
              item.standaloneLyric!,
              style: TextStyle(
                fontSize: fontSize * 0.95,
                fontStyle: FontStyle.italic,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          );
        }

        // 3. Sistema de Partitura (Pauta musical de 5 linhas com Clave de Sol, acordes e compassos)
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.sectionMarker != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * scale),
                  child: Text(
                    item.sectionMarker!,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
              _StaffSystemWidget(
                measures: item.measures,
                scale: scale,
                fontSize: fontSize,
                showClef: true,
                showTimeSignature: item.isStartOfSong || index == 0,
                isDark: isDark,
                scheme: scheme,
                onChordTap: onChordTap,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Converte o texto da música em sistemas de partitura musical com compassos.
  static List<ScoreSystemItem> _parseContentToScoreSystems(String content, int transpose) {
    final clean = ChordTransposer.cleanText(content);
    final rawLines = clean.replaceAll('\r\n', '\n').split('\n');

    final List<ScoreSystemItem> result = [];
    String? pendingSectionMarker;
    bool isFirstMeasure = true;

    int i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i].trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Marcador de seção ([Refrão], [Intro], etc.)
      if (ChordTransposer.isMarker(trimmed) || RegExp(r'^\[.*\]$').hasMatch(trimmed)) {
        pendingSectionMarker = trimmed;
        i++;
        continue;
      }

      // Linha de acordes
      if (ChordTransposer.isChordLine(line)) {
        // Verifica se a próxima linha é uma linha de letra
        String? nextLyric;
        if (i + 1 < rawLines.length) {
          final nextLine = rawLines[i + 1].trimRight();
          if (nextLine.isNotEmpty &&
              !ChordTransposer.isChordLine(nextLine) &&
              !ChordTransposer.isMarker(nextLine.trim())) {
            nextLyric = nextLine;
            i++; // Consome a linha de letra acompanhante
          }
        }

        // Extrai os acordes e suas posições na linha
        final chordMatches = RegExp(r'\S+').allMatches(line).toList();
        final List<_ParsedChordToken> chordTokens = [];

        for (final m in chordMatches) {
          final token = m.group(0)!;
          final parsed = ChordTransposer.parseTokenChord(token);
          if (parsed != null) {
            final transposedChord = transpose == 0
                ? parsed.chord
                : ChordTransposer.transposeChord(parsed.chord, transpose);
            chordTokens.add(_ParsedChordToken(
              chord: transposedChord,
              rawChord: parsed.chord,
              startCol: m.start,
              endCol: m.end,
            ));
          }
        }

        if (chordTokens.isNotEmpty) {
          // Cria os compassos alinhando cada acorde com seu respectivo fragmento de letra
          final List<ScoreMeasure> measures = [];

          for (int c = 0; c < chordTokens.length; c++) {
            final cur = chordTokens[c];
            final nextCol = (c + 1 < chordTokens.length)
                ? chordTokens[c + 1].startCol
                : (nextLyric != null ? nextLyric.length : cur.endCol + 15);

            String measureLyric = '';
            if (nextLyric != null && nextLyric.isNotEmpty) {
              final start = cur.startCol.clamp(0, nextLyric.length);
              final end = nextCol.clamp(start, nextLyric.length);
              measureLyric = nextLyric.substring(start, end).trim();
            }

            final notes = _calculateChordNotes(cur.chord);
            measures.add(ScoreMeasure(
              chord: cur.chord,
              rawChord: cur.rawChord,
              notes: notes,
              lyrics: measureLyric,
            ));
          }

          // Se a linha tiver muitos acordes (ex: mais de 4), quebramos em sistemas de até 4 compassos
          const int maxMeasuresPerSystem = 4;
          for (int mIdx = 0; mIdx < measures.length; mIdx += maxMeasuresPerSystem) {
            final endIdx = (mIdx + maxMeasuresPerSystem).clamp(0, measures.length);
            final chunk = measures.sublist(mIdx, endIdx);
            result.add(ScoreSystemItem.measures(
              measures: chunk,
              sectionMarker: mIdx == 0 ? pendingSectionMarker : null,
              isStartOfSong: isFirstMeasure,
            ));
            isFirstMeasure = false;
          }
          pendingSectionMarker = null;
        }

        i++;
        continue;
      }

      // Linha de letra avulsa sem acordes
      final cleanLyrics = line.replaceAll(RegExp(r'\[[A-G][b#]?[^\]]*\]'), '').trim();
      if (cleanLyrics.isNotEmpty) {
        if (pendingSectionMarker != null) {
          result.add(ScoreSystemItem.section(pendingSectionMarker));
          pendingSectionMarker = null;
        }
        result.add(ScoreSystemItem.lyric(cleanLyrics));
      }

      i++;
    }

    return result;
  }

  /// Calcula as notas musicais que formam o acorde e suas posições na pauta.
  static List<ScoreNote> _calculateChordNotes(String chordStr) {
    final cleaned = ChordTransposer.cleanChordForLookup(chordStr);
    final match = RegExp(r'^([A-Ga-g][#b]?)(.*)$').firstMatch(cleaned);
    if (match == null) return const [];

    final root = match.group(1)!;
    final quality = match.group(2)?.toLowerCase() ?? '';

    // Mapeamento básico da nota raiz (C4 a B4)
    final rootStep = _noteToStep(root);
    final accidental = root.contains('#') ? '#' : (root.contains('b') ? 'b' : null);

    final isMinor = quality.startsWith('m') && !quality.startsWith('maj');
    final isDim = quality.contains('dim') || quality.contains('°') || quality.contains('º');
    final isAug = quality.contains('aug') || quality.contains('+');
    final has7 = quality.contains('7');
    final hasMaj7 = quality.contains('7m') || quality.contains('maj7') || quality.contains('7+');

    // Intervalos da tríade/tétrade em semitons e passos diatônicos (linhas/espaços)
    // Passo fundamental (terça e quinta diatônicas são sempre +2 e +4 passos na pauta)
    final List<ScoreNote> notes = [];

    // Tônica
    notes.add(ScoreNote(
      name: root,
      step: rootStep,
      accidental: accidental,
    ));

    // Terça (sempre 2 passos diatônicos acima da tônica)
    final thirdStep = rootStep + 2;
    String? thirdAcc;
    if (isMinor || isDim) {
      if (accidental == '#') {
        thirdAcc = null; // Terça menor de C# é E natural
      } else if (accidental == null && (root == 'C' || root == 'F' || root == 'G')) {
        thirdAcc = 'b'; // Terça menor de C, F, G leva bemol (Eb, Ab, Bb)
      }
    } else {
      // Maior
      if (root == 'D' || root == 'E' || root == 'A' || root == 'B') {
        thirdAcc = '#'; // F#, G#, C#, D#
      }
    }
    notes.add(ScoreNote(
      name: '3ª',
      step: thirdStep,
      accidental: thirdAcc,
    ));

    // Quinta (sempre 4 passos diatônicos acima da tônica)
    final fifthStep = rootStep + 4;
    String? fifthAcc;
    if (isDim) {
      fifthAcc = (accidental == '#') ? null : 'b';
    } else if (isAug) {
      fifthAcc = '#';
    } else if (root == 'B') {
      fifthAcc = '#'; // B -> F#
    }
    notes.add(ScoreNote(
      name: '5ª',
      step: fifthStep,
      accidental: fifthAcc,
    ));

    // Sétima (opcional, +6 passos diatônicos)
    if (has7 || hasMaj7) {
      final seventhStep = rootStep + 6;
      String? sevAcc;
      if (hasMaj7) {
        if (root == 'C' || root == 'F') {
          sevAcc = null;
        } else {
          sevAcc = '#';
        }
      } else {
        if (root == 'C' || root == 'F') {
          sevAcc = 'b';
        }
      }
      notes.add(ScoreNote(
        name: '7ª',
        step: seventhStep,
        accidental: sevAcc,
      ));
    }

    return notes;
  }

  /// Retorna o passo da pauta para a nota base:
  /// C4 = 0 (Linha suplementar inferior)
  /// D4 = 1 (Espaço abaixo da pauta)
  /// E4 = 2 (Linha 1)
  /// F4 = 3 (Espaço 1)
  /// G4 = 4 (Linha 2)
  /// A4 = 5 (Espaço 2)
  /// B4 = 6 (Linha 3)
  static int _noteToStep(String noteName) {
    final base = noteName[0].toUpperCase();
    switch (base) {
      case 'C': return 0;
      case 'D': return 1;
      case 'E': return 2;
      case 'F': return 3;
      case 'G': return 4;
      case 'A': return 5;
      case 'B': return 6;
      default: return 0;
    }
  }
}

class _ParsedChordToken {
  final String chord;
  final String rawChord;
  final int startCol;
  final int endCol;

  _ParsedChordToken({
    required this.chord,
    required this.rawChord,
    required this.startCol,
    required this.endCol,
  });
}

/// Widget que renderiza visualmente um sistema de pauta musical (Staff) com compassos
class _StaffSystemWidget extends StatelessWidget {
  const _StaffSystemWidget({
    required this.measures,
    required this.scale,
    required this.fontSize,
    required this.showClef,
    required this.showTimeSignature,
    required this.isDark,
    required this.scheme,
    required this.onChordTap,
  });

  final List<ScoreMeasure> measures;
  final double scale;
  final double fontSize;
  final bool showClef;
  final bool showTimeSignature;
  final bool isDark;
  final ColorScheme scheme;
  final void Function(String chord) onChordTap;

  @override
  Widget build(BuildContext context) {
    final staffColor = isDark ? Colors.white70 : const Color(0xFF2C3E50);
    final cardBg = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : const Color(0xFFFCFBF7); // Papel de partitura sutilmente aquecido

    final lineSpacing = 8.5 * scale;
    final staffHeight = lineSpacing * 4;
    final topStaffOffset = 34.0 * scale; // Espaço acima da pauta para cifras e notas altas
    final bottomStaffOffset = 36.0 * scale; // Espaço abaixo da pauta para letras e notas baixas
    final totalHeight = topStaffOffset + staffHeight + bottomStaffOffset;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2DEC9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 10 * scale,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final clefWidth = showClef ? (38.0 * scale) : 8.0 * scale;
          final timeSigWidth = showTimeSignature ? (28.0 * scale) : 0.0;
          final headerWidth = clefWidth + timeSigWidth;
          final measuresWidth = (totalWidth - headerWidth).clamp(60.0, double.infinity);
          final measureWidth = measures.isNotEmpty ? (measuresWidth / measures.length) : measuresWidth;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              children: [
                // 1. Pintura das 5 Linhas da Pauta, Clave de Sol e Linhas de Compasso
                CustomPaint(
                  size: Size(totalWidth, totalHeight),
                  painter: _StaffPainter(
                    topOffset: topStaffOffset,
                    lineSpacing: lineSpacing,
                    staffColor: staffColor,
                    headerWidth: headerWidth,
                    measureWidth: measureWidth,
                    measureCount: measures.length,
                    showClef: showClef,
                    showTimeSignature: showTimeSignature,
                    scale: scale,
                    scheme: scheme,
                    measures: measures,
                  ),
                ),

                // 2. Acordes clicáveis acima de cada compasso
                Positioned(
                  top: 0,
                  left: headerWidth,
                  right: 0,
                  child: Row(
                    children: measures.map((m) {
                      return SizedBox(
                        width: measureWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 10 * scale),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => onChordTap(ChordTransposer.cleanChordForLookup(m.chord)),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
                                  child: Text(
                                    m.chord,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: (fontSize * 0.95).clamp(13.0, 24.0),
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 3. Letras abaixo de cada compasso
                Positioned(
                  bottom: 0,
                  left: headerWidth,
                  right: 0,
                  child: Row(
                    children: measures.map((m) {
                      return SizedBox(
                        width: measureWidth,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                          child: Text(
                            m.lyrics,
                            style: TextStyle(
                              fontSize: (fontSize * 0.82).clamp(11.0, 20.0),
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Pintor customizado que renderiza a pauta musical com 5 linhas, clave de sol, compassos e notas
class _StaffPainter extends CustomPainter {
  _StaffPainter({
    required this.topOffset,
    required this.lineSpacing,
    required this.staffColor,
    required this.headerWidth,
    required this.measureWidth,
    required this.measureCount,
    required this.showClef,
    required this.showTimeSignature,
    required this.scale,
    required this.scheme,
    required this.measures,
  });

  final double topOffset;
  final double lineSpacing;
  final Color staffColor;
  final double headerWidth;
  final double measureWidth;
  final int measureCount;
  final bool showClef;
  final bool showTimeSignature;
  final double scale;
  final ColorScheme scheme;
  final List<ScoreMeasure> measures;

  @override
  void paint(Canvas canvas, Size size) {
    final staffPaint = Paint()
      ..color = staffColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.0 * scale
      ..style = PaintingStyle.stroke;

    final barLinePaint = Paint()
      ..color = staffColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.4 * scale
      ..style = PaintingStyle.stroke;

    // 1. Desenha as 5 Linhas Horizontais da Pauta
    for (int i = 0; i < 5; i++) {
      final y = topOffset + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), staffPaint);
    }

    // Linha de início vertical
    canvas.drawLine(
      Offset(0, topOffset),
      Offset(0, topOffset + 4 * lineSpacing),
      barLinePaint,
    );

    // 2. Clave de Sol (𝄞)
    if (showClef) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '𝄞',
          style: TextStyle(
            fontSize: 38 * scale,
            color: staffColor,
            fontFamily: 'serif',
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Alinha a espiral da clave de sol exatamente na segunda linha (G4)
      final clefY = topOffset - (11 * scale);
      textPainter.paint(canvas, Offset(4 * scale, clefY));
    }

    // 3. Fórmula de Compasso (4/4 clássico)
    if (showTimeSignature) {
      final startX = (showClef ? (32.0 * scale) : 4.0 * scale);
      final numPainter = TextPainter(
        text: TextSpan(
          text: '4',
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.bold,
            color: staffColor,
            fontFamily: 'serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 4 superior (linhas 3 e 4)
      numPainter.paint(canvas, Offset(startX, topOffset + 2 * scale));
      // 4 inferior (linhas 1 e 2)
      numPainter.paint(canvas, Offset(startX, topOffset + 2 * lineSpacing + 2 * scale));
    }

    // 4. Barras de Compasso Verticais (|)
    for (int i = 1; i <= measureCount; i++) {
      final x = (headerWidth + (i * measureWidth)).clamp(0.0, size.width);
      final isFinalBar = (i == measureCount);

      if (isFinalBar) {
        // Barra dupla final elegante
        canvas.drawLine(
          Offset(x - (3 * scale), topOffset),
          Offset(x - (3 * scale), topOffset + 4 * lineSpacing),
          barLinePaint,
        );
        final heavyBarPaint = Paint()
          ..color = staffColor.withValues(alpha: 0.8)
          ..strokeWidth = 2.8 * scale
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(x, topOffset),
          Offset(x, topOffset + 4 * lineSpacing),
          heavyBarPaint,
        );
      } else {
        canvas.drawLine(
          Offset(x, topOffset),
          Offset(x, topOffset + 4 * lineSpacing),
          barLinePaint,
        );
      }
    }

    // 5. Desenho das Notas Musicais dos Acordes em Cada Compasso
    for (int m = 0; m < measures.length; m++) {
      final measure = measures[m];
      if (measure.notes.isEmpty) continue;

      final measureStartX = headerWidth + (m * measureWidth);
      final noteCenterX = measureStartX + (measureWidth * 0.42);

      _drawChordNotesOnStaff(
        canvas: canvas,
        notes: measure.notes,
        centerX: noteCenterX,
        topOffset: topOffset,
        lineSpacing: lineSpacing,
      );
    }
  }

  /// Desenha a cabeça das notas que compõem o acorde na pauta musical.
  void _drawChordNotesOnStaff({
    required Canvas canvas,
    required List<ScoreNote> notes,
    required double centerX,
    required double topOffset,
    required double lineSpacing,
  }) {
    final noteWidth = 10.5 * scale;
    final noteHeight = lineSpacing * 0.94;
    final halfSpace = lineSpacing / 2.0;

    // Linha 1 (E4) fica na parte inferior da pauta: topOffset + 4 * lineSpacing
    final bottomLineY = topOffset + (4 * lineSpacing);

    final notePaint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 1.8 * scale
      ..style = PaintingStyle.stroke;

    final noteFillPaint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final ledgerLinePaint = Paint()
      ..color = staffColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke;

    for (final note in notes) {
      // E4 = step 2 -> y = bottomLineY
      // C4 = step 0 -> y = bottomLineY + 2 * halfSpace = bottomLineY + lineSpacing (1 linha suplementar inferior)
      final y = bottomLineY - ((note.step - 2) * halfSpace);

      // Linhas suplementares (C4 ou A5)
      if (note.step <= 0) {
        // C4 (step 0) -> linha suplementar inferior
        final ledgerY = bottomLineY + lineSpacing;
        canvas.drawLine(
          Offset(centerX - (noteWidth * 0.8), ledgerY),
          Offset(centerX + (noteWidth * 0.8), ledgerY),
          ledgerLinePaint,
        );
      } else if (note.step >= 12) {
        // A5 (step 12) -> linha suplementar superior
        final ledgerY = topOffset - lineSpacing;
        canvas.drawLine(
          Offset(centerX - (noteWidth * 0.8), ledgerY),
          Offset(centerX + (noteWidth * 0.8), ledgerY),
          ledgerLinePaint,
        );
      }

      // Salva o canvas para desenhar a nota musical ovalada e inclinada
      canvas.save();
      canvas.translate(centerX, y);
      canvas.rotate(-0.25); // ~ -15 graus

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: noteWidth,
        height: noteHeight,
      );

      // Cabeça de semibreve (nota aberta)
      canvas.drawOval(rect, noteFillPaint);
      canvas.drawOval(rect, notePaint);

      canvas.restore();

      // Acidente (# ou b)
      if (note.accidental != null) {
        final accPainter = TextPainter(
          text: TextSpan(
            text: note.accidental == '#' ? '♯' : '♭',
            style: TextStyle(
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
              fontFamily: 'serif',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        accPainter.paint(
          canvas,
          Offset(centerX - noteWidth - (8 * scale), y - (9 * scale)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StaffPainter old) {
    return old.topOffset != topOffset ||
        old.lineSpacing != lineSpacing ||
        old.staffColor != staffColor ||
        old.headerWidth != headerWidth ||
        old.measureWidth != measureWidth ||
        old.measureCount != measureCount ||
        old.scale != scale ||
        old.measures != measures;
  }
}
