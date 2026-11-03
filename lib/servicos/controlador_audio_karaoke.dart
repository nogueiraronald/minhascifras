import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../modelos/musica.dart';
import 'transpositor_acordes.dart';

/// Representa uma linha da música mapeada com timestamp exato do áudio
class TimedSongLine {
  final Duration startTime;
  final int lyricLineIndex;
  final int? chordLineIndex;
  final String text;
  final bool isChord;

  const TimedSongLine({
    required this.startTime,
    required this.lyricLineIndex,
    required this.chordLineIndex,
    required this.text,
    this.isChord = false,
  });

  int get lineIndex => isChord ? (chordLineIndex ?? lyricLineIndex) : lyricLineIndex;
}

/// Seção da música com estrofe, acorde associado e palavras de conteúdo para interpretação
class _KaraokeSection {
  final int lyricLineIndex;
  final int? chordLineIndex;
  final String lyricText;
  final Set<String> contentWords;

  const _KaraokeSection({
    required this.lyricLineIndex,
    required this.chordLineIndex,
    required this.lyricText,
    required this.contentWords,
  });
}

/// Controlador completo que integra reprodução nativa de áudio (YouTube / MP3)
/// e rolagem sincronizada com detecção de palavras e destaque exclusivo de acordes ou letra.
class KaraokeAudioController extends ChangeNotifier {
  KaraokeAudioController({
    required this.song,
    required this.scrollController,
    AudioPlayer? player,
    this.enableNativeAudio = true,
  }) : _player = player {
    _init();
  }

  final Song song;
  final bool enableNativeAudio;
  ScrollController scrollController;

  void updateScrollController(ScrollController newController) {
    scrollController = newController;
    _syncScroll();
  }

  AudioPlayer? _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  bool _isDisposed = false;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  String? _errorMessage;
  String? _resolvedStreamUrl;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isAutoScrollEnabled = true;
  double _volume = 1.0;
  bool _isMuted = false;

  // Sincronização por palavras via legendas do YouTube
  List<ClosedCaption> _captions = [];
  final List<TimedSongLine> _timedLines = [];
  final List<int> _chordLineIndices = [];
  final List<int> _lyricsLineIndices = [];
  Duration? _firstVocalTimestamp;

  bool get isPlaying => _isPlaying;
  bool get isLoadingAudio => _isLoadingAudio;
  String? get errorMessage => _errorMessage;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get progress {
    if (_totalDuration.inMilliseconds <= 0) return 0.0;
    return (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }
  bool get isAutoScrollEnabled => _isAutoScrollEnabled;
  double get volume => _volume;
  bool get isMuted => _isMuted;

  bool get isYoutube => song.audioType == 'youtube';
  bool get isNativeAudio => true;

  void toggleAutoScroll() {
    _isAutoScrollEnabled = !_isAutoScrollEnabled;
    notifyListeners();
  }

  Future<void>? _preloadFuture;

  void _init() {
    // Configura duração inicial se definida no modelo
    if (song.audioDurationSeconds != null && song.audioDurationSeconds! > 0) {
      _totalDuration = Duration(seconds: song.audioDurationSeconds!);
    } else {
      _totalDuration = const Duration(minutes: 3, seconds: 30);
    }

    _buildLineIndices();

    if (enableNativeAudio) {
      _initNativePlayer();
      if (song.hasAudio && isYoutube) {
        _preloadFuture = _preloadCaptionsAndAudio();
      }
    }
  }

  /// Identifica os índices das linhas de acordes e de letra da música,
  /// excluindo metadados de cabeçalho (Título e Artista) antes do início da música.
  void _buildLineIndices() {
    _chordLineIndices.clear();
    _lyricsLineIndices.clear();

    final clean = ChordTransposer.cleanText(song.content);
    final lines = clean.replaceAll('\r\n', '\n').split('\n');

    int firstMusicLine = -1;
    for (int i = 0; i < lines.length; i++) {
      if (ChordTransposer.isChordLine(lines[i]) || ChordTransposer.isMarker(lines[i])) {
        firstMusicLine = i;
        break;
      }
    }

    final titleNorm = song.title.trim().toLowerCase();
    final artistNorm = song.artist.trim().toLowerCase();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      if (ChordTransposer.isChordLine(line)) {
        _chordLineIndices.add(i);
      } else if (!ChordTransposer.isMarker(line) && !RegExp(r'^\[.*\]$').hasMatch(line.trim())) {
        // Ignora cabeçalhos de título/artista antes do início real da música
        if (firstMusicLine != -1 && i < firstMusicLine) continue;
        final norm = line.trim().toLowerCase();
        if (titleNorm.isNotEmpty && norm == titleNorm) continue;
        if (artistNorm.isNotEmpty && norm == artistNorm) continue;
        _lyricsLineIndices.add(i);
      }
    }

    _buildSections();
  }

  /// Pré-carrega legendas e fluxo de áudio do YouTube em segundo plano
  Future<void> _preloadCaptionsAndAudio() async {
    if (!song.hasAudio || !isYoutube) return;
    final url = song.audioUrl!.trim();

    try {
      final yt = YoutubeExplode();
      final ytId = Song.extractYoutubeVideoId(url) ?? url;
      final videoId = VideoId(ytId);

      try {
        final video = await yt.videos.get(videoId);
        if (video.duration != null && video.duration! > Duration.zero) {
          _totalDuration = video.duration!;
          notifyListeners();
        }
      } catch (_) {}

      // Obtém legendas e constrói o mapeamento por fluxo contínuo de palavras
      try {
        final captionManifest = await yt.videos.closedCaptions.getManifest(videoId);
        ClosedCaptionTrackInfo? selectedTrack;
        final ptTracks = captionManifest.getByLanguage('pt');
        if (ptTracks.isNotEmpty) {
          selectedTrack = ptTracks.first;
        } else if (captionManifest.tracks.isNotEmpty) {
          selectedTrack = captionManifest.tracks.first;
        }

        if (selectedTrack != null) {
          final track = await yt.videos.closedCaptions.get(selectedTrack);
          _captions = track.captions.toList();
          _buildKaraokeTimeline();
          _detectFirstVocalTimestamp();
          _updateDynamicMatching(_currentPosition);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Legendas não disponíveis para este vídeo: $e');
      }

      // Pré-resolve a URL da stream de áudio
      if (_resolvedStreamUrl == null) {
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        StreamInfo? streamToPlay;
        final muxedMp4 = manifest.muxed.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
        if (muxedMp4.isNotEmpty) {
          streamToPlay = muxedMp4.first;
        } else {
          final audioMp4 = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
          if (audioMp4.isNotEmpty) {
            streamToPlay = audioMp4.withHighestBitrate();
          } else {
            streamToPlay = manifest.audioOnly.withHighestBitrate();
          }
        }
        _resolvedStreamUrl = streamToPlay.url.toString();
      }
      yt.close();
    } catch (e) {
      debugPrint('Erro no pré-carregamento do YouTube: $e');
    }
  }

  // Seções da cifra mapeadas para interpretação dinâmica do áudio
  final List<_KaraokeSection> _sections = [];
  int? _activeDynamicChord;
  int? _activeDynamicLyric;

  @visibleForTesting
  List<TimedSongLine> get timedLinesForTesting => _timedLines;

  @visibleForTesting
  void setCaptionsForTesting(List<ClosedCaption> captions) {
    _captions = captions;
    _buildKaraokeTimeline();
    _detectFirstVocalTimestamp();
    _updateDynamicMatching(_currentPosition);
    notifyListeners();
  }

  static String _normalizeWord(String w) {
    return w
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static const Set<String> _portugueseStopWords = {
    'que', 'para', 'com', 'por', 'dos', 'das', 'nos', 'nas', 'aos', 'uma', 'uns', 'umas',
    'seu', 'sua', 'seus', 'suas', 'meu', 'minha', 'meus', 'minhas', 'teu', 'tua', 'teus', 'tuas',
    'ele', 'ela', 'eles', 'elas', 'este', 'esta', 'isto', 'esse', 'essa', 'isso', 'aquele', 'aquela',
    'foi', 'eram', 'mais', 'como', 'quando', 'onde', 'quem', 'qual', 'quais', 'quanto',
    'muito', 'muita', 'muitos', 'muitas', 'tudo', 'nada', 'cada', 'todo', 'toda', 'todos', 'todas',
    'ate', 'pelo', 'pela', 'pelos', 'pelas', 'num', 'numa', 'bem', 'mas', 'nem',
    'sim', 'nao', 'aqui', 'alem', 'sobre', 'sob', 'tras', 'sem', 'pois', 'ainda',
    'sao', 'era', 'vai', 'vou', 'tem', 'ter', 'ser', 'estar', 'estao', 'estava', 'estive',
    'dar', 'deu', 'fazer', 'fez', 'dizer', 'disse', 'veja', 'olha',
  };

  /// Constrói seções da cifra com palavras-chave de conteúdo para interpretação do áudio
  void _buildSections() {
    _sections.clear();
    final clean = ChordTransposer.cleanText(song.content);
    final lines = clean.replaceAll('\r\n', '\n').split('\n');

    for (final lIdx in _lyricsLineIndices) {
      if (lIdx >= lines.length) continue;
      final line = lines[lIdx];
      final words = line
          .split(RegExp(r'\s+'))
          .map(_normalizeWord)
          .where((w) => w.length >= 3 && !_portugueseStopWords.contains(w))
          .toSet();

      int? chordIdx;
      for (int c = lIdx - 1; c >= 0; c--) {
        if (lines[c].trim().isEmpty) continue;
        if (ChordTransposer.isChordLine(lines[c])) {
          chordIdx = c;
          break;
        }
        break;
      }

      _sections.add(_KaraokeSection(
        lyricLineIndex: lIdx,
        chordLineIndex: chordIdx,
        lyricText: line,
        contentWords: words,
      ));
    }
  }

  static bool _isFuzzyMatch(String a, String b) {
    if (a == b) return true;
    if ((a.length - b.length).abs() > 2) return false;
    if (a.length < 4 || b.length < 4) return false;
    int p = 0;
    while (p < a.length && p < b.length && a[p] == b[p]) {
      p++;
    }
    int s = 0;
    while (s < a.length - p && s < b.length - p && a[a.length - 1 - s] == b[b.length - 1 - s]) {
      s++;
    }
    return (a.length - p - s) <= 2 && (b.length - p - s) <= 2;
  }

  /// Constrói a linha do tempo sequencial e precisa do karaokê a partir das legendas
  void _buildKaraokeTimeline() {
    _timedLines.clear();
    _firstVocalTimestamp = null;
    if (_captions.isEmpty || _sections.isEmpty) return;

    int currentSecIdx = 0;

    for (int i = 0; i < _captions.length; i++) {
      final cap = _captions[i];
      final combinedWords = <String>{};
      final earliestTime = cap.offset;

      // Janela deslizante para captar a frase cantada completa
      for (int j = i; j < _captions.length && j <= i + 2; j++) {
        if (_captions[j].offset - cap.offset > const Duration(seconds: 4)) break;
        final w = _captions[j].text
            .split(RegExp(r'\s+'))
            .map(_normalizeWord)
            .where((w) => w.length >= 3 && !_portugueseStopWords.contains(w));
        combinedWords.addAll(w);
      }

      if (combinedWords.isEmpty) continue;

      _KaraokeSection? bestSec;
      int bestScore = 0;
      double bestRatio = 0.0;
      int bestIdx = -1;

      for (int sIdx = 0; sIdx < _sections.length; sIdx++) {
        final s = _sections[sIdx];
        if (s.contentWords.isEmpty) continue;

        final matches = s.contentWords
            .where((sw) => combinedWords.any((cw) => _isFuzzyMatch(cw, sw)))
            .length;
        final ratio = matches / s.contentWords.length;

        final bool isSignificant;
        if (s.contentWords.length >= 3) {
          isSignificant = matches >= 3 || (matches >= 2 && ratio >= 0.5);
        } else if (s.contentWords.length == 2) {
          isSignificant = matches == 2 || (matches == 1 && ratio >= 0.5);
        } else {
          isSignificant = matches == 1 && (sIdx == currentSecIdx || sIdx == currentSecIdx + 1);
        }

        if (isSignificant) {
          int score = matches * 10;
          if (sIdx == currentSecIdx + 1) {
            score += 5; // Favorece a progressão sequencial natural da música
          } else if (sIdx == currentSecIdx) {
            score += 3;
          }

          if (score > bestScore || (score == bestScore && ratio > bestRatio)) {
            bestScore = score;
            bestRatio = ratio;
            bestSec = s;
            bestIdx = sIdx;
          }
        }
      }

      if (bestSec != null) {
        // Evita duplicar o mesmo evento se ele acabou de ser registrado há menos de 4s
        if (_timedLines.isNotEmpty &&
            _timedLines.last.lyricLineIndex == bestSec.lyricLineIndex &&
            earliestTime - _timedLines.last.startTime < const Duration(seconds: 4)) {
          continue;
        }

        _timedLines.add(TimedSongLine(
          startTime: earliestTime,
          lyricLineIndex: bestSec.lyricLineIndex,
          chordLineIndex: bestSec.chordLineIndex,
          text: bestSec.lyricText,
        ));
        currentSecIdx = bestIdx;
      }
    }

    if (_timedLines.isNotEmpty) {
      _firstVocalTimestamp = _timedLines.first.startTime;
    }
  }

  /// Detecta exatamente quando o canto começa, ignorando discursos/falas na introdução
  void _detectFirstVocalTimestamp() {
    if (_timedLines.isNotEmpty) {
      _firstVocalTimestamp = _timedLines.first.startTime;
      return;
    }
    _firstVocalTimestamp = null;
    if (_captions.isEmpty || _sections.isEmpty) return;

    for (final c in _captions) {
      final words = c.text
          .split(RegExp(r'\s+'))
          .map(_normalizeWord)
          .where((w) => w.length >= 3 && !_portugueseStopWords.contains(w))
          .toSet();

      for (final s in _sections) {
        if (s.contentWords.isEmpty) continue;
        final matches = s.contentWords.where((w) => words.contains(w)).length;
        final ratio = matches / s.contentWords.length;

        final bool isSignificant;
        if (s.contentWords.length >= 3) {
          isSignificant = matches >= 3 || (matches >= 2 && ratio >= 0.6);
        } else if (s.contentWords.length == 2) {
          isSignificant = matches == 2;
        } else {
          isSignificant = false;
        }

        if (isSignificant) {
          _firstVocalTimestamp = c.offset;
          return;
        }
      }
    }
  }

  /// Interpreta dinamicamente o áudio na posição atual e identifica o trecho cantado
  void _updateDynamicMatching(Duration position) {
    if (_timedLines.isNotEmpty) {
      if (_firstVocalTimestamp != null && position < _firstVocalTimestamp!) {
        _activeDynamicChord = _chordLineIndices.isNotEmpty ? _chordLineIndices.first : null;
        _activeDynamicLyric = null;
        return;
      }
      final past = _timedLines.where((t) => t.startTime <= position);
      if (past.isNotEmpty) {
        _activeDynamicChord = past.last.chordLineIndex ?? (_chordLineIndices.isNotEmpty ? _chordLineIndices.first : null);
        _activeDynamicLyric = past.last.lyricLineIndex;
        return;
      }
    }

    if (_captions.isEmpty || _sections.isEmpty) return;

    // Se ainda estamos na introdução instrumental ou falada antes do início do canto
    if (_firstVocalTimestamp != null && position < _firstVocalTimestamp!) {
      _activeDynamicChord = _chordLineIndices.isNotEmpty ? _chordLineIndices.first : null;
      _activeDynamicLyric = null;
      return;
    }

    // Janela temporal em torno da posição atual [position - 4s, position + 2s]
    final windowStart = position - const Duration(seconds: 4);
    final windowEnd = position + const Duration(seconds: 2);

    final activeCaptions = _captions.where((c) {
      final cStart = c.offset;
      final cEnd = c.offset + c.duration;
      return cEnd >= windowStart && cStart <= windowEnd;
    }).toList();

    if (activeCaptions.isEmpty) return;

    // Extrai palavras-chave de conteúdo da fala/canto no momento
    final audioWords = <String>{};
    for (final c in activeCaptions) {
      final words = c.text
          .split(RegExp(r'\s+'))
          .map(_normalizeWord)
          .where((w) => w.length >= 3 && !_portugueseStopWords.contains(w));
      audioWords.addAll(words);
    }

    if (audioWords.isEmpty) return;

    _KaraokeSection? bestSection;
    int bestScore = 0;
    double bestRatio = 0.0;

    for (final s in _sections) {
      if (s.contentWords.isEmpty) continue;
      final matches = s.contentWords.where((w) => audioWords.contains(w)).length;
      final ratio = matches / s.contentWords.length;

      final isContinuation = _activeDynamicLyric != null &&
          (s.lyricLineIndex - _activeDynamicLyric!).abs() <= 3;

      final bool isSignificant;
      if (s.contentWords.length >= 3) {
        isSignificant = matches >= 3 || (matches >= 2 && ratio >= 0.6);
      } else if (s.contentWords.length == 2) {
        isSignificant = matches == 2;
      } else {
        isSignificant = matches == 1 && isContinuation;
      }

      if (isSignificant) {
        if (matches > bestScore || (matches == bestScore && ratio > bestRatio)) {
          bestScore = matches;
          bestRatio = ratio;
          bestSection = s;
        }
      }
    }

    if (bestSection != null) {
      _activeDynamicChord = bestSection.chordLineIndex ?? _activeDynamicChord;
      _activeDynamicLyric = bestSection.lyricLineIndex;
    }
  }

  /// Retorna o índice da linha de ACORDES ativa no momento (para modo Cifra)
  int? get activeChordLineIndex {
    if (_chordLineIndices.isEmpty) return null;

    // 1. Linha do tempo sequencial e precisa do karaokê
    if (_timedLines.isNotEmpty) {
      if (_firstVocalTimestamp != null && _currentPosition < _firstVocalTimestamp!) {
        return _chordLineIndices.first;
      }
      final past = _timedLines.where((t) => t.startTime <= _currentPosition);
      if (past.isNotEmpty) {
        return past.last.chordLineIndex ?? _chordLineIndices.first;
      }
      return _chordLineIndices.first;
    }

    // 2. Interpretação em tempo real das legendas/áudio
    if (_captions.isNotEmpty) {
      if (_firstVocalTimestamp != null && _currentPosition < _firstVocalTimestamp!) {
        return _chordLineIndices.first;
      }
      return _activeDynamicChord ?? _chordLineIndices.first;
    }

    // 3. Fallback proporcional seguro (apenas entre linhas de acordes)
    final idx = (_chordLineIndices.length * progress).floor().clamp(0, _chordLineIndices.length - 1);
    return _chordLineIndices[idx];
  }

  /// Retorna o índice da linha de LETRA ativa no momento (para modo Letra)
  int? get activeLyricsLineIndex {
    if (_lyricsLineIndices.isEmpty) return null;

    // 1. Linha do tempo sequencial e precisa do karaokê
    if (_timedLines.isNotEmpty) {
      if (_firstVocalTimestamp != null && _currentPosition < _firstVocalTimestamp!) {
        return null; // O canto ainda não começou (introdução)
      }
      final past = _timedLines.where((t) => t.startTime <= _currentPosition);
      if (past.isNotEmpty) {
        return past.last.lyricLineIndex;
      }
      return null;
    }

    // 2. Interpretação em tempo real das legendas/áudio
    if (_captions.isNotEmpty) {
      if (_firstVocalTimestamp != null && _currentPosition < _firstVocalTimestamp!) {
        return null; // O canto ainda não começou (introdução)
      }
      return _activeDynamicLyric ?? _lyricsLineIndices.first;
    }

    // 3. Fallback proporcional seguro (apenas entre linhas de letra)
    final idx = (_lyricsLineIndices.length * progress).floor().clamp(0, _lyricsLineIndices.length - 1);
    return _lyricsLineIndices[idx];
  }

  void _initNativePlayer() {
    _player ??= AudioPlayer();

    try {
      _durSub = _player!.onDurationChanged.listen((dur) {
        if (dur > Duration.zero) {
          _totalDuration = dur;
          notifyListeners();
        }
      });

      _posSub = _player!.onPositionChanged.listen((pos) {
        _currentPosition = pos;
        _updateDynamicMatching(pos);
        _syncScroll();
        notifyListeners();
      });

      _stateSub = _player!.onPlayerStateChanged.listen((state) {
        _isPlaying = state == PlayerState.playing;
        notifyListeners();
      });

      _completeSub = _player!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _syncScroll();
        notifyListeners();
      });
    } catch (_) {}
  }

  /// Inicia ou pausa a reprodução sincronizada
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (!song.hasAudio) return;

    final url = song.audioUrl!.trim();

    // 1. YouTube: resolve áudio real em MP4/AAC e obtém legendas temporizadas
    if (isYoutube) {
      if (_resolvedStreamUrl == null) {
        _isLoadingAudio = true;
        _errorMessage = null;
        notifyListeners();

        // Se o pré-carregamento estiver em andamento, aguarda sua conclusão
        if (_preloadFuture != null) {
          try {
            await _preloadFuture;
          } catch (_) {}
        }

        // Se ainda não tiver resolvido, faz a extração direta
        if (_resolvedStreamUrl == null) {
          try {
            final yt = YoutubeExplode();
            final ytId = Song.extractYoutubeVideoId(url) ?? url;
            final videoId = VideoId(ytId);

            try {
              final video = await yt.videos.get(videoId);
              if (video.duration != null && video.duration! > Duration.zero) {
                _totalDuration = video.duration!;
              }
            } catch (_) {}

            if (_captions.isEmpty) {
              try {
                final captionManifest = await yt.videos.closedCaptions.getManifest(videoId);
                ClosedCaptionTrackInfo? selectedTrack;
                final ptTracks = captionManifest.getByLanguage('pt');
                if (ptTracks.isNotEmpty) {
                  selectedTrack = ptTracks.first;
                } else if (captionManifest.tracks.isNotEmpty) {
                  selectedTrack = captionManifest.tracks.first;
                }

                if (selectedTrack != null) {
                  final track = await yt.videos.closedCaptions.get(selectedTrack);
                  _captions = track.captions.toList();
                  _detectFirstVocalTimestamp();
                  _updateDynamicMatching(_currentPosition);
                }
              } catch (e) {
                debugPrint('Legendas não disponíveis para este vídeo: $e');
              }
            }

            final manifest = await yt.videos.streamsClient.getManifest(videoId);
            StreamInfo? streamToPlay;
            final muxedMp4 = manifest.muxed.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
            if (muxedMp4.isNotEmpty) {
              streamToPlay = muxedMp4.first;
            } else {
              final audioMp4 = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
              if (audioMp4.isNotEmpty) {
                streamToPlay = audioMp4.withHighestBitrate();
              } else {
                streamToPlay = manifest.audioOnly.withHighestBitrate();
              }
            }

            _resolvedStreamUrl = streamToPlay.url.toString();
            yt.close();
          } catch (e) {
            debugPrint('Erro ao extrair áudio do YouTube: $e');
            _isLoadingAudio = false;
            _errorMessage = 'Não foi possível carregar áudio do YouTube.';
            _isPlaying = false;
            notifyListeners();
            return;
          }
        }

        _isLoadingAudio = false;
      }

      if (_resolvedStreamUrl != null && _player != null) {
        try {
          await _player!.setVolume(_isMuted ? 0.0 : _volume);
          await _player!.play(UrlSource(_resolvedStreamUrl!));
          if (_currentPosition > Duration.zero) {
            await _player!.seek(_currentPosition);
          }
          _isPlaying = true;
          _isLoadingAudio = false;
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Erro ao reproduzir stream do YouTube: $e');
          _resolvedStreamUrl = null;
        }
      }
    }

    // 2. MP3 / Arquivo Local / URL direta de áudio
    if (song.audioType == 'mp3' && _player != null) {
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        await _player!.play(UrlSource(url));
      } else {
        final cleanPath = url.replaceFirst(RegExp(r'^file://'), '');
        final file = File(cleanPath);
        if (await file.exists()) {
          await _player!.play(DeviceFileSource(cleanPath));
        } else {
          await _player!.play(DeviceFileSource(url));
        }
      }
      if (_currentPosition > Duration.zero) {
        await _player!.seek(_currentPosition);
      }
      _isPlaying = true;
      notifyListeners();
      return;
    }
  }

  Future<void> pause() async {
    if (_player != null) {
      try {
        await _player!.pause().timeout(const Duration(milliseconds: 200), onTimeout: () {});
      } catch (_) {}
    }
    _isPlaying = false;
    notifyListeners();
  }

  /// Pula/busca para uma posição específica
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    if (_currentPosition > _totalDuration) {
      _currentPosition = _totalDuration;
    }
    if (_currentPosition < Duration.zero) {
      _currentPosition = Duration.zero;
    }

    if (enableNativeAudio && _player != null) {
      try {
        await _player!.seek(_currentPosition).timeout(const Duration(milliseconds: 200), onTimeout: () {});
      } catch (_) {}
    }

    _updateDynamicMatching(position);
    _syncScroll();
    notifyListeners();
  }

  /// Avança ou volta N segundos (+10s, -10s, etc.)
  Future<void> seekRelative(int seconds) async {
    final nextMs = _currentPosition.inMilliseconds + (seconds * 1000);
    await seek(Duration(milliseconds: nextMs));
  }

  /// Reinicia a música do início
  Future<void> restart() async {
    _activeDynamicChord = _chordLineIndices.isNotEmpty ? _chordLineIndices.first : null;
    _activeDynamicLyric = null;
    await seek(Duration.zero);
  }

  /// Ajusta o volume (0.0 a 1.0)
  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    _isMuted = false;
    if (_player != null) {
      try {
        await _player!.setVolume(_volume).timeout(const Duration(milliseconds: 200), onTimeout: () {});
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Alterna mudo do áudio
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_player != null) {
      try {
        await _player!.setVolume(_isMuted ? 0.0 : _volume).timeout(const Duration(milliseconds: 200), onTimeout: () {});
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Calcula o índice da linha ativa na cifra com base no progresso temporal (fallback ou genérico)
  int calculateActiveLine(int totalLines, [List<String>? lines]) {
    if (totalLines <= 0) return 0;
    if (_totalDuration.inMilliseconds <= 0) return 0;
    var idx = (totalLines * progress).floor().clamp(0, totalLines - 1);

    if (lines != null && lines.isNotEmpty && idx < lines.length && lines[idx].trim().isEmpty) {
      if (idx + 1 < lines.length && lines[idx + 1].trim().isNotEmpty) {
        idx = idx + 1;
      } else if (idx - 1 >= 0 && lines[idx - 1].trim().isNotEmpty) {
        idx = idx - 1;
      }
    }
    return idx;
  }

  /// Pula o áudio diretamente para a linha clicada pelo usuário
  Future<void> seekToLine(int lineIndex, [int? totalLines]) async {
    // Se temos timestamps reais alinhados com essa linha ou seu acorde
    final match = _timedLines.where((t) => t.lyricLineIndex == lineIndex || t.chordLineIndex == lineIndex).firstOrNull;
    if (match != null) {
      await seek(match.startTime);
      return;
    }

    final total = totalLines ?? song.content.split('\n').length;
    if (total <= 0) return;
    final progress = (lineIndex / total).clamp(0.0, 1.0);
    await seekProgress(progress);
  }

  /// Pula o áudio proporcionalmente para o percentual informado (0.0 a 1.0)
  Future<void> seekProgress(double progress) async {
    final targetMs = (_totalDuration.inMilliseconds * progress.clamp(0.0, 1.0)).round();
    await seek(Duration(milliseconds: targetMs));
  }

  /// Abre o link no app externo oficial
  Future<bool> openExternalApp() async {
    if (!song.hasAudio) return false;
    final clean = Song.cleanAudioUrl(song.audioUrl!.trim());
    if (clean == null) return false;
    final uri = Uri.tryParse(clean);
    if (uri != null) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        return ok;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Sincroniza a rolagem da cifra diretamente com a linha ativa da música.
  /// A rolagem com centralização precisa no meio exato da tela (alignment: 0.5)
  /// é realizada com perfeição geométrica pelos visualizadores (ChordSheetView e LyricsView)
  /// através de Scrollable.ensureVisible, garantindo que qualquer trecho cantado (mesmo a última linha)
  /// fique visível e centralizado sem cortes ou saltos excessivos.
  void _syncScroll() {}

  @override
  void dispose() {
    _isDisposed = true;
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    try {
      _player?.stop();
      _player?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
