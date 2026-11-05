// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

import '../servicos/controlador_audio_karaoke.dart';

final Map<String, html.IFrameElement> _registeredIframes = {};

Widget buildYoutubePlayerView({
  required BuildContext context,
  required String videoId,
  KaraokeAudioController? controller,
  VoidCallback? onClose,
  bool isInteracting = false,
}) {
  return _YoutubePlayerEmbedView(
    videoId: videoId,
    controller: controller,
    onClose: onClose,
    isInteracting: isInteracting,
  );
}

class _YoutubePlayerEmbedView extends StatefulWidget {
  const _YoutubePlayerEmbedView({
    required this.videoId,
    this.controller,
    this.onClose,
    this.isInteracting = false,
  });

  final String videoId;
  final KaraokeAudioController? controller;
  final VoidCallback? onClose;
  final bool isInteracting;

  @override
  State<_YoutubePlayerEmbedView> createState() => _YoutubePlayerEmbedViewState();
}

class _YoutubePlayerEmbedViewState extends State<_YoutubePlayerEmbedView> {
  StreamSubscription<html.MessageEvent>? _messageSub;
  Timer? _progressPollTimer;
  late String _viewType;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewType = 'youtube-iframe-${widget.videoId}';
    _setupIframe();
    _attachController();
    _startMessageListener();
    _updateIframePointerEvents();
  }

  @override
  void didUpdateWidget(covariant _YoutubePlayerEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _viewType = 'youtube-iframe-${widget.videoId}';
      _detachController(oldWidget.controller);
      _setupIframe();
      _attachController();
    } else if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController();
    }
    if (oldWidget.isInteracting != widget.isInteracting) {
      _updateIframePointerEvents();
    }
  }

  void _updateIframePointerEvents() {
    _iframe?.style.pointerEvents = widget.isInteracting ? 'none' : 'auto';
  }

  void _setupIframe() {
    if (!_registeredIframes.containsKey(widget.videoId)) {
      final origin = html.window.location.origin;
      final iframe = html.IFrameElement()
        ..id = 'yt-embed-${widget.videoId}'
        ..src = 'https://www.youtube.com/embed/${widget.videoId}?enablejsapi=1&autoplay=1&playsinline=1&origin=$origin'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;

      iframe.onLoad.listen((_) {
        _sendIframeCommand(iframe, 'listening');
      });

      _registeredIframes[widget.videoId] = iframe;

      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return iframe;
      });
    }

    _iframe = _registeredIframes[widget.videoId];
    _updateIframePointerEvents();
  }

  void _attachController() {
    final c = widget.controller;
    if (c == null) return;

    c.onPlayYoutube = () {
      _sendPlayerCommand('playVideo');
    };

    c.onPauseYoutube = () {
      _sendPlayerCommand('pauseVideo');
    };

    c.onSeekYoutube = (position) {
      final seconds = position.inMilliseconds / 1000.0;
      _sendPlayerCommand('seekTo', [seconds, true]);
    };

    c.onVolumeYoutube = (volume) {
      final volInt = (volume * 100).round().clamp(0, 100);
      _sendPlayerCommand('setVolume', [volInt]);
    };

    c.onMuteYoutube = (isMuted) {
      _sendPlayerCommand(isMuted ? 'mute' : 'unMute');
    };
  }

  void _detachController(KaraokeAudioController? c) {
    if (c == null) return;
    c.onPlayYoutube = null;
    c.onPauseYoutube = null;
    c.onSeekYoutube = null;
    c.onVolumeYoutube = null;
    c.onMuteYoutube = null;
  }

  void _sendIframeCommand(html.IFrameElement? iframe, String command, [List<dynamic> args = const []]) {
    if (iframe?.contentWindow == null) return;
    try {
      final payload = jsonEncode({
        'event': command == 'listening' ? 'listening' : 'command',
        if (command != 'listening') 'func': command,
        if (command != 'listening') 'args': args,
      });
      iframe!.contentWindow!.postMessage(payload, '*');
    } catch (_) {}
  }

  void _sendPlayerCommand(String func, [List<dynamic> args = const []]) {
    _sendIframeCommand(_iframe, func, args);
  }

  Timer? _pauseDebounceTimer;

  void _handlePlayerState(dynamic state) {
    if (state == 1) {
      _pauseDebounceTimer?.cancel();
      widget.controller?.onYoutubeStateChanged(isPlaying: true);
    } else if (state == 0) {
      _pauseDebounceTimer?.cancel();
      widget.controller?.onYoutubeStateChanged(isPlaying: false);
    } else if (state == 2) {
      // Debounce suave para evitar que pequenos bufferings de 200ms congelem o karaokê
      _pauseDebounceTimer?.cancel();
      _pauseDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        widget.controller?.onYoutubeStateChanged(isPlaying: false);
      });
    }
  }

  void _startMessageListener() {
    _messageSub?.cancel();
    _messageSub = html.window.onMessage.listen((event) {
      if (event.data is! String) return;
      try {
        final raw = jsonDecode(event.data as String);
        if (raw is! Map) return;

        final eventName = raw['event'];

        if (eventName == 'infoDelivery' && raw['info'] is Map) {
          final info = raw['info'] as Map;
          if (info.containsKey('currentTime')) {
            final curSec = (info['currentTime'] as num).toDouble();
            final durSec = info.containsKey('duration') ? (info['duration'] as num).toDouble() : null;

            widget.controller?.updateYoutubePlayback(
              position: Duration(milliseconds: (curSec * 1000).toInt()),
              duration: durSec != null && durSec > 0
                  ? Duration(milliseconds: (durSec * 1000).toInt())
                  : null,
            );
          }

          if (info.containsKey('playerState')) {
            _handlePlayerState(info['playerState']);
          }
        } else if (eventName == 'onStateChange') {
          _handlePlayerState(raw['info']);
        }
      } catch (_) {}
    });

    // Envia sinal periódico de listening para manter a entrega de eventos do YouTube ativa
    _progressPollTimer?.cancel();
    _progressPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_iframe != null) {
        _sendIframeCommand(_iframe, 'listening');
      }
    });
  }

  @override
  void dispose() {
    _pauseDebounceTimer?.cancel();
    _messageSub?.cancel();
    _progressPollTimer?.cancel();
    _iframe?.style.pointerEvents = 'auto';
    _detachController(widget.controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
