import 'dart:async';

import 'package:video_player/video_player.dart';

import 'playback_service.dart';

/// Default [PlaybackService] backed by `video_player` (ExoPlayer on Android,
/// AVPlayer on iOS). Handles HLS/DASH/MPEG-TS/progressive and injects the
/// streaming User-Agent header. The later UI attaches a `VideoPlayer` widget to
/// [controller]. No UI is built here.
class VideoPlayerPlaybackService implements PlaybackService {
  VideoPlayerController? _controller;
  final _stateController = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = PlaybackState.idle;

  VideoPlayerController? get controller => _controller;

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;

  @override
  Future<void> load(PlaybackSource source) async {
    await _disposeController();
    _emit(const PlaybackState(status: PlaybackStatus.buffering));
    final c = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
      httpHeaders: source.headers,
    );
    _controller = c;
    c.addListener(_onControllerUpdate);
    try {
      await c.initialize();
      _emit(PlaybackState(
        status: PlaybackStatus.paused,
        duration: c.value.duration,
      ));
    } catch (e) {
      _emit(PlaybackState(status: PlaybackStatus.error, errorMessage: 'Load failed'));
      rethrow;
    }
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      _emit(PlaybackState(status: PlaybackStatus.error, errorMessage: 'Playback error'));
      return;
    }
    final status = !v.isInitialized
        ? PlaybackStatus.buffering
        : v.isBuffering
            ? PlaybackStatus.buffering
            : v.isPlaying
                ? PlaybackStatus.playing
                : (v.position >= v.duration && v.duration > Duration.zero)
                    ? PlaybackStatus.ended
                    : PlaybackStatus.paused;
    _emit(PlaybackState(
      status: status,
      position: v.position,
      duration: v.duration,
    ));
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> stop() async {
    final c = _controller;
    if (c != null) {
      await c.pause();
      await c.seekTo(Duration.zero);
    }
    _emit(PlaybackState.idle);
  }

  @override
  Future<void> dispose() async {
    await _disposeController();
    await _stateController.close();
  }

  Future<void> _disposeController() async {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onControllerUpdate);
      await c.dispose();
      _controller = null;
    }
  }

  void _emit(PlaybackState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }
}
