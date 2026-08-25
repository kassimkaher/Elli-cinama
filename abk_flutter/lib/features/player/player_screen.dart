import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../core/player/playback_service.dart';
import '../../core/player/video_player_playback_service.dart';
import '../../shared/widgets/buttons.dart';
import '../catalogue/catalogue_providers.dart';
import '../epg/domain/entities.dart';
import '../favorites/playback_history_repository.dart';

/// One item in a player playlist (a channel, a movie, or an episode).
class PlaybackItem {
  final String url;
  final String title;
  final String? subtitle;
  final bool live;
  final int? streamId; // live: for short-EPG
  final String resumeId; // resume/history key ('' = no resume)
  final String kind; // live | movie | episode
  final String? image;

  const PlaybackItem({
    required this.url,
    required this.title,
    this.subtitle,
    this.live = false,
    this.streamId,
    this.resumeId = '',
    this.kind = '',
    this.image,
  });
}

/// Production player for live + VOD (Design §31/§41/§51). Always dark. Supports
/// a playlist: live channel up/down switching, VOD next (episode) + auto-advance,
/// resume (seek to saved offset, periodic save), and a Now/Next EPG strip that
/// appears only when data exists. Uses the existing [PlaybackService].
class PlayerScreen extends ConsumerStatefulWidget {
  final List<PlaybackItem> items;
  final int index;
  const PlayerScreen({super.key, required this.items, this.index = 0});

  /// Convenience for a single item.
  PlayerScreen.single(PlaybackItem item, {super.key})
      : items = [item],
        index = 0;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver {
  late final PlaybackService _svc = ref.read(playbackServiceProvider);
  late int _i = widget.index;
  StreamSubscription<PlaybackState>? _sub;
  PlaybackState _state = const PlaybackState(status: PlaybackStatus.buffering);
  bool _controls = true, _fullscreen = false, _failed = false;
  Timer? _hide, _save;
  List<EpgListing> _epg = const [];

  PlaybackItem get _item => widget.items[_i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _svc.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if (s.status == PlaybackStatus.ended && !_item.live && _i < widget.items.length - 1) {
        _go(1);
      }
    });
    _save = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
    _open();
    _bumpControls();
  }

  Future<void> _open() async {
    setState(() {
      _failed = false;
      _epg = const [];
    });
    final item = _item;
    if (item.resumeId.isNotEmpty && item.kind.isNotEmpty) {
      ref.read(playbackHistoryRepositoryProvider).record(PlaybackEntry(
            id: item.resumeId, kind: item.kind, title: item.title,
            subtitle: item.subtitle ?? '', image: item.image,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
      ref.read(localRevisionProvider.notifier).state++;
    }
    try {
      final src = ref.read(playbackSourceFactoryProvider).fromUrl(item.url, title: item.title);
      await _svc.load(src).timeout(const Duration(seconds: 20));
      // Resume VOD from the saved offset.
      if (!item.live && item.resumeId.isNotEmpty) {
        final saved = await ref.read(resumeRepositoryProvider).getPosition(item.resumeId);
        final svc = _svc;
        if (saved != null && saved > 5 && svc is VideoPlayerPlaybackService) {
          final dur = svc.controller?.value.duration.inSeconds ?? 0;
          if (dur == 0 || saved < dur - 10) {
            await svc.controller?.seekTo(Duration(seconds: saved));
          }
        }
      }
      await _svc.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    // EPG (only rendered when data exists).
    if (item.live && item.streamId != null) {
      ref.read(shortEpgProvider(item.streamId!).future).then((list) {
        if (mounted && _item.streamId == item.streamId) setState(() => _epg = list);
      }).ignore();
    }
  }

  void _persist() {
    final item = _item;
    final svc = _svc;
    if (item.live || item.resumeId.isEmpty || svc is! VideoPlayerPlaybackService) return;
    final v = svc.controller?.value;
    if (v == null || !v.isInitialized || v.duration.inSeconds <= 0) return;
    final pos = v.position.inSeconds;
    ref.read(resumeRepositoryProvider).setPosition(item.resumeId, pos);
    if (item.kind.isNotEmpty) {
      ref.read(playbackHistoryRepositoryProvider).record(PlaybackEntry(
            id: item.resumeId, kind: item.kind, title: item.title,
            subtitle: item.subtitle ?? '', image: item.image,
            progress: (pos / v.duration.inSeconds).clamp(0, 1),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
    }
  }

  void _go(int delta) {
    final next = _i + delta;
    if (next < 0 || next >= widget.items.length) return;
    _persist();
    setState(() => _i = next);
    _open();
    _bumpControls();
  }

  bool get _hasPrev => _i > 0;
  bool get _hasNext => _i < widget.items.length - 1;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _svc.pause();
  }

  @override
  void dispose() {
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    _hide?.cancel();
    _save?.cancel();
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
              SingleActivator(LogicalKeyboardKey.arrowUp): _PrevIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): _NextIntent(),
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
                _PrevIntent: CallbackAction<_PrevIntent>(onInvoke: (_) { _go(-1); return null; }),
                _NextIntent: CallbackAction<_NextIntent>(onInvoke: (_) { _go(1); return null; }),
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
                          (_state.status == PlaybackStatus.buffering || _state.status == PlaybackStatus.idle))
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
          Text(context.tr(_item.live ? 'preparing' : 'loading'),
              style: context.type.caption.copyWith(color: Colors.white70)),
        ]),
      );

  Widget _error(dynamic c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AbkSpace.s24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, color: c.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(context.tr('streamFailed'), style: context.type.sectionTitle.copyWith(color: Colors.white)),
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, children: [
              AbkButton(context.tr('retry'), icon: Icons.refresh_rounded, onPressed: _open),
              const SizedBox(width: 12),
              AbkButton(context.tr('back'), kind: AbkButtonKind.ghost, onPressed: () => Navigator.of(context).maybePop()),
            ]),
          ]),
        ),
      );

  Widget _overlay(dynamic c) {
    final now = _epg.isNotEmpty ? _epg[0].title : null;
    final next = _epg.length > 1 ? _epg[1].title : null;
    return AnimatedOpacity(
      opacity: _controls ? 1 : 0,
      duration: _controls ? AbkMotion.searchIn : AbkMotion.overlayOut,
      child: IgnorePointer(
        ignoring: !_controls,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                IconButton(onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: context.type.cardTitle.copyWith(color: Colors.white)),
                    if (now != null)
                      Text('${context.tr('liveBadge')}: $now', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(color: c.accentPrimary))
                    else if (_item.subtitle != null)
                      Text(_item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(color: Colors.white70)),
                    if (next != null)
                      Text('› $next', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(color: Colors.white54)),
                  ]),
                ),
                if (_item.live)
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
            ),
            child: SafeArea(
              top: false,
              child: Column(children: [
                if (!_item.live) _progress(c),
                Row(children: [
                  // Live channel up/down or VOD prev/next episode.
                  if (widget.items.length > 1) ...[
                    IconButton(
                      onPressed: _hasPrev ? () => _go(-1) : null,
                      icon: Icon(_item.live ? Icons.keyboard_arrow_up_rounded : Icons.skip_previous_rounded,
                          color: _hasPrev ? Colors.white : Colors.white30),
                    ),
                    IconButton(
                      onPressed: _hasNext ? () => _go(1) : null,
                      icon: Icon(_item.live ? Icons.keyboard_arrow_down_rounded : Icons.skip_next_rounded,
                          color: _hasNext ? Colors.white : Colors.white30),
                    ),
                  ],
                  IconButton(
                    onPressed: () {
                      _state.status == PlaybackStatus.playing ? _svc.pause() : _svc.play();
                      _bumpControls();
                    },
                    icon: Icon(_state.status == PlaybackStatus.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 34),
                  ),
                  if (!_item.live)
                    Text('${_fmt(_state.position)} / ${_fmt(_state.duration)}',
                        style: context.type.playerControl.copyWith(color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
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

class _PlayPauseIntent extends Intent { const _PlayPauseIntent(); }
class _FsIntent extends Intent { const _FsIntent(); }
class _EscIntent extends Intent { const _EscIntent(); }
class _PrevIntent extends Intent { const _PrevIntent(); }
class _NextIntent extends Intent { const _NextIntent(); }
