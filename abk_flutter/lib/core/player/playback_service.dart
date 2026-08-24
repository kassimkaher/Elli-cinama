// Presentation-independent playback abstraction. The later UI phase consumes
// this; no player widget is built here.

enum StreamContainer { hls, dash, mpegTs, progressive, unknown }

enum PlaybackStatus { idle, buffering, playing, paused, ended, error }

class PlaybackState {
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  const PlaybackState({
    required this.status,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  static const idle = PlaybackState(status: PlaybackStatus.idle);
}

class PlaybackSource {
  final String url;
  final Map<String, String> headers;
  final StreamContainer container;
  final String? title;

  const PlaybackSource({
    required this.url,
    this.headers = const {},
    this.container = StreamContainer.unknown,
    this.title,
  });
}

abstract class PlaybackService {
  Future<void> load(PlaybackSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
  Stream<PlaybackState> get stateStream;
  PlaybackState get state;
}

/// URL-based container detection. Extension-less live URLs (Xtream
/// `/{user}/{pass}/{id}`) return [StreamContainer.unknown] so the player infers
/// the type at runtime (typically MPEG-TS via redirect).
StreamContainer detectContainer(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.m3u8')) return StreamContainer.hls;
  if (path.endsWith('.mpd')) return StreamContainer.dash;
  if (path.endsWith('.ts')) return StreamContainer.mpegTs;
  if (path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.avi')) {
    return StreamContainer.progressive;
  }
  return StreamContainer.unknown;
}
