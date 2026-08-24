import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../core/player/playback_service.dart';
import '../../core/player/video_player_playback_service.dart';
import '../../shared/widgets/buttons.dart';
import '../../core/di/providers.dart';
import '../catalogue/catalogue_providers.dart';
import '../favorites/playback_history_repository.dart';

/// One player screen for live and VOD (Design §31/§41/§51). Always dark. The
/// video surface stays mounted through every state; the design's controls
/// (identity/switch/recover for live; timeline/seek/quality for VOD) adapt to
/// the mode. Uses the existing [PlaybackService] abstraction.
class PlayerScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final String? subtitle;
  final bool live;
  final PlaybackEntry? history;
  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.subtitle,
    this.live = false,
    this.history,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlaybackService _svc = ref.read(playbackServiceProvider);
  StreamSubscription<PlaybackState>? _sub;
  PlaybackState _state = const PlaybackState(status: PlaybackStatus.buffering);
  bool _controls = true;
  bool _fullscreen = false;
  bool _failed = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _sub = _svc.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _load();
    _bumpControls();
    // Record continue-watching (optimistic, local).
    if (widget.history != null) {
      ref.read(playbackHistoryRepositoryProvider).record(widget.history!);
      ref.read(localRevisionProvider.notifier).state++;
    }
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final src = ref.read(playbackSourceFactoryProvider).fromUrl(widget.url, title: widget.title);
      await _svc.load(src).timeout(const Duration(seconds: 15));
      await _svc.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _bumpControls() {
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    await SystemChrome.setEnabledSystemUIMode(
        _fullscreen ? SystemUiMode.immersive : SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _sub?.cancel();
    _svc.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlwaysDark(
      child: Builder(builder: (context) {
        final c = context.c;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.space): _PlayPauseIntent(),
              SingleActivator(LogicalKeyboardKey.keyF): _FsIntent(),
              SingleActivator(LogicalKeyboardKey.escape): _EscIntent(),
            },
            child: Actions(
              actions: {
                _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(onInvoke: (_) {
                  _state.status == PlaybackStatus.playing ? _svc.pause() : _svc.play();
                  _bumpControls();
                  return null;
                }),
                _FsIntent: CallbackAction<_FsIntent>(onInvoke: (_) { _toggleFullscreen(); return null; }),
                _EscIntent: CallbackAction<_EscIntent>(onInvoke: (_) {
                  if (_fullscreen) { _toggleFullscreen(); } else { Navigator.of(context).maybePop(); }
                  return null;
                }),
              },
              child: Focus(
                autofocus: true,
                child: MouseRegion(
                  onHover: (_) => _bumpControls(),
                  child: GestureDetector(
                    onTap: () => setState(() => _controls = !_controls),
                    child: Stack(fit: StackFit.expand, children: [
                      const ColoredBox(color: Colors.black),
                      _surface(),
                      if (!_failed &&
                          (_state.status == PlaybackStatus.buffering ||
                              _state.status == PlaybackStatus.idle))
                        _buffering(c),
                      if (_failed || _state.status == PlaybackStatus.error) _error(c),
                      _overlay(c),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _surface() {
    final svc = _svc;
    if (svc is VideoPlayerPlaybackService) {
      final ctrl = svc.controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio == 0 ? 16 / 9 : ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buffering(dynamic c) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: c.accentPrimary),
          const SizedBox(height: 16),
          Text(context.tr(widget.live ? 'preparing' : 'loading'),
              style: context.type.caption.copyWith(color: Colors.white70)),
        ]),
      );

  Widget _error(dynamic c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AbkSpace.s24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, color: c.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(context.tr('streamFailed'),
                style: context.type.sectionTitle.copyWith(color: Colors.white)),
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, children: [
              AbkButton(context.tr('retry'), icon: Icons.refresh_rounded, onPressed: _load),
              const SizedBox(width: 12),
              AbkButton(context.tr('back'), kind: AbkButtonKind.ghost, onPressed: () => Navigator.of(context).maybePop()),
            ]),
          ]),
        ),
      );

  Widget _overlay(dynamic c) {
    return AnimatedOpacity(
      opacity: _controls ? 1 : 0,
      duration: _controls ? AbkMotion.searchIn : AbkMotion.overlayOut,
      child: IgnorePointer(
        ignoring: !_controls,
        child: Column(children: [
          // Top: identity + close.
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: context.type.cardTitle.copyWith(color: Colors.white)),
                    if (widget.subtitle != null)
                      Text(widget.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(color: Colors.white70)),
                  ]),
                ),
                if (widget.live)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: c.accentSecondary, borderRadius: AbkRadius.brXs),
                    child: Text(context.tr('liveBadge'),
                        style: context.type.metadata.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          ),
          const Spacer(),
          // Bottom: controls.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
            ),
            child: SafeArea(
              top: false,
              child: Column(children: [
                if (!widget.live) _progress(c),
                Row(children: [
                  IconButton(
                    onPressed: () {
                      _state.status == PlaybackStatus.playing ? _svc.pause() : _svc.play();
                      _bumpControls();
                    },
                    icon: Icon(
                        _state.status == PlaybackStatus.playing
                            ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 34),
                  ),
                  if (!widget.live)
                    Text(
                      '${_fmt(_state.position)} / ${_fmt(_state.duration)}',
                      style: context.type.playerControl.copyWith(color: Colors.white),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        color: Colors.white),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _progress(dynamic c) {
    final dur = _state.duration.inMilliseconds;
    final pos = _state.position.inMilliseconds;
    final v = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: c.accentPrimary,
        inactiveTrackColor: Colors.white24,
        thumbColor: c.accentPrimary,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      child: Slider(
        value: v,
        onChanged: dur > 0
            ? (nv) {
                final svc = _svc;
                if (svc is VideoPlayerPlaybackService) {
                  svc.controller?.seekTo(Duration(milliseconds: (nv * dur).round()));
                }
                _bumpControls();
              }
            : null,
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _FsIntent extends Intent {
  const _FsIntent();
}

class _EscIntent extends Intent {
  const _EscIntent();
}
