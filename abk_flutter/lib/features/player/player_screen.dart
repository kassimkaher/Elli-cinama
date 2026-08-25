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
import '../favorites/resume_repository.dart';

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

/// Production player for live + VOD. Always dark. Supports a playlist: live
/// channel up/down switching (debounced for surfing, no races), VOD next/prev
/// episode + auto-advance, resume, double-tap ±10s seek, smooth scrubbing
/// (seek on release), and a Now/Next EPG strip. A coherent phase model drives a
/// visible state at all times — never a silent/stuck screen.
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

/// Coherent player phase — always one visible state, never silent/stuck.
enum _Phase { preparing, buffering, playing, paused, switchingSource, error }

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  // Captured in initState so dispose()/timers never touch `ref` after disposal.
  late final PlaybackService _svc = ref.read(playbackServiceProvider);
  late final ResumeRepository _resumeRepo = ref.read(resumeRepositoryProvider);
  late final PlaybackHistoryRepository _historyRepo =
      ref.read(playbackHistoryRepositoryProvider);
  late int _i = widget.index;

  StreamSubscription<PlaybackState>? _sub;
  PlaybackState _state = const PlaybackState(status: PlaybackStatus.buffering);

  bool _controls = true;
  bool _fullscreen = false;
  bool _switching = false; // a source switch is in flight
  bool _failed = false; // load failed → error/retry
  int _gen = 0; // supersedes stale async from a prior source

  bool _dragging = false; // scrubbing the seek bar
  double _dragValue = 0; // 0..1 target while dragging
  Timer? _hide, _save, _switchTimer, _seekFlashTimer;
  int _seekFlash = 0; // -1 (−10s) / +1 (+10s) transient badge

  List<EpgListing> _epg = const [];

  PlaybackItem get _item => widget.items[_i];
  bool get _seekable => !_item.live && _state.duration > Duration.zero;

  _Phase get _phase {
    if (_failed || _state.status == PlaybackStatus.error) return _Phase.error;
    if (_switching) return _Phase.switchingSource;
    switch (_state.status) {
      case PlaybackStatus.playing:
        return _Phase.playing;
      case PlaybackStatus.paused:
        return _Phase.paused;
      case PlaybackStatus.ended:
        return _Phase.playing;
      case PlaybackStatus.idle:
        return _Phase.preparing;
      case PlaybackStatus.buffering:
        return _Phase.buffering;
      case PlaybackStatus.error:
        return _Phase.error;
    }
  }

  bool get _showSpinner =>
      _phase == _Phase.preparing ||
      _phase == _Phase.buffering ||
      _phase == _Phase.switchingSource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Force-initialise captured providers now (ref is valid) so dispose() and
    // the periodic save timer never read a disposed ref.
    _resumeRepo;
    _historyRepo;
    _sub = _svc.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      // VOD auto-advance to the next episode on natural completion.
      if (s.status == PlaybackStatus.ended &&
          !_item.live &&
          !_switching &&
          _hasNext) {
        _go(1);
      }
    });
    _save = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
    // Defer first open to after the first frame — it records history / bumps a
    // provider, which must not happen during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _open();
        _bumpControls();
      }
    });
  }

  // ---- source lifecycle -----------------------------------------------------

  Future<void> _open() async {
    final gen = ++_gen; // this attempt owns the controller
    if (mounted) {
      setState(() {
        _failed = false;
        _epg = const [];
      });
    }
    final item = _item;

    if (item.resumeId.isNotEmpty && item.kind.isNotEmpty) {
      _historyRepo.record(PlaybackEntry(
            id: item.resumeId,
            kind: item.kind,
            title: item.title,
            subtitle: item.subtitle ?? '',
            image: item.image,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
      ref.read(localRevisionProvider.notifier).state++;
    }

    try {
      final src =
          ref.read(playbackSourceFactoryProvider).fromUrl(item.url, title: item.title);
      await _svc.load(src).timeout(const Duration(seconds: 25));
      if (gen != _gen) return; // superseded by a newer switch → drop

      // Resume VOD from the saved offset (through the abstraction).
      if (!item.live && item.resumeId.isNotEmpty) {
        final saved = await _resumeRepo.getPosition(item.resumeId);
        if (gen != _gen) return;
        final dur = _svc.state.duration.inSeconds;
        if (saved != null && saved > 5 && (dur == 0 || saved < dur - 10)) {
          await _svc.seek(Duration(seconds: saved));
        }
      }
      await _svc.play();
      if (gen != _gen) return;
      if (mounted) setState(() => _switching = false);
    } catch (_) {
      if (gen != _gen) return;
      if (mounted) {
        setState(() {
          _failed = true;
          _switching = false;
        });
      }
    }

    // EPG (only rendered when data exists).
    if (item.live && item.streamId != null) {
      ref.read(shortEpgProvider(item.streamId!).future).then((list) {
        if (mounted && gen == _gen) setState(() => _epg = list);
      }).ignore();
    }
  }

  /// Move by [delta] in the playlist. Rapid presses are debounced so surfing
  /// several channels issues exactly one load (no concurrent loads → no hang).
  void _go(int delta) {
    final next = _i + delta;
    if (next < 0 || next >= widget.items.length) return;
    _persist();
    setState(() {
      _i = next;
      _switching = true;
      _failed = false;
      _epg = const [];
    });
    _bumpControls();
    _switchTimer?.cancel();
    _switchTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _open();
    });
  }

  void _persist() {
    final item = _item;
    if (item.live || item.resumeId.isEmpty) return;
    final dur = _state.duration.inSeconds;
    if (dur <= 0) return;
    final pos = _state.position.inSeconds;
    _resumeRepo.setPosition(item.resumeId, pos);
    if (item.kind.isNotEmpty) {
      _historyRepo.record(PlaybackEntry(
            id: item.resumeId,
            kind: item.kind,
            title: item.title,
            subtitle: item.subtitle ?? '',
            image: item.image,
            progress: (pos / dur).clamp(0, 1),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
    }
  }

  bool get _hasPrev => _i > 0;
  bool get _hasNext => _i < widget.items.length - 1;

  // ---- seek -----------------------------------------------------------------

  void _seekBy(int seconds) {
    if (!_seekable) return;
    final target = _state.position + Duration(seconds: seconds);
    _svc.seek(target);
    setState(() => _seekFlash = seconds < 0 ? -1 : 1);
    _seekFlashTimer?.cancel();
    _seekFlashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _seekFlash = 0);
    });
    _bumpControls();
  }

  void _onDoubleTapZone(TapDownDetails d, double width) {
    if (!_seekable) return;
    final left = d.localPosition.dx < width / 2;
    _seekBy(left ? -10 : 10);
  }

  // ---- controls / lifecycle -------------------------------------------------

  void _bumpControls() {
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && !_dragging) setState(() => _controls = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    await SystemChrome.setEnabledSystemUIMode(
        _fullscreen ? SystemUiMode.immersive : SystemUiMode.edgeToEdge);
  }

  void _togglePlay() {
    _state.status == PlaybackStatus.playing ? _svc.pause() : _svc.play();
    _bumpControls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _svc.pause();
    }
  }

  @override
  void dispose() {
    _gen++; // invalidate any in-flight load so it cannot touch a disposed state
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    _hide?.cancel();
    _save?.cancel();
    _switchTimer?.cancel();
    _seekFlashTimer?.cancel();
    _sub?.cancel();
    _svc.stop(); // full release → no lingering audio, no orphan decoder
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AlwaysDark(
      child: Builder(builder: (context) {
        final c = context.c;
        return PopScope(
          // BACK exits fullscreen, then hides controls, then leaves the player.
          canPop: !_controls && !_fullscreen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_fullscreen) {
              _toggleFullscreen();
            } else if (_controls) {
              setState(() => _controls = false);
            }
          },
          child: Scaffold(
          backgroundColor: Colors.black,
          body: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.space): _PlayPauseIntent(),
              SingleActivator(LogicalKeyboardKey.mediaPlayPause): _PlayPauseIntent(),
              SingleActivator(LogicalKeyboardKey.keyF): _FsIntent(),
              SingleActivator(LogicalKeyboardKey.escape): _EscIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp): _PrevIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): _NextIntent(),
              SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): _PrevIntent(),
              SingleActivator(LogicalKeyboardKey.mediaTrackNext): _NextIntent(),
              SingleActivator(LogicalKeyboardKey.arrowLeft): _Back10Intent(),
              SingleActivator(LogicalKeyboardKey.arrowRight): _Fwd10Intent(),
              // D-pad OK / SELECT.
              SingleActivator(LogicalKeyboardKey.select): _SelectIntent(),
              SingleActivator(LogicalKeyboardKey.gameButtonA): _SelectIntent(),
            },
            child: Actions(
              actions: {
                _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
                    onInvoke: (_) {
                  _togglePlay();
                  return null;
                }),
                _SelectIntent: CallbackAction<_SelectIntent>(onInvoke: (_) {
                  // OK reveals the controls; when already shown, toggles play.
                  if (_controls) {
                    _togglePlay();
                  } else {
                    _bumpControls();
                  }
                  return null;
                }),
                _FsIntent: CallbackAction<_FsIntent>(onInvoke: (_) {
                  _toggleFullscreen();
                  return null;
                }),
                _EscIntent: CallbackAction<_EscIntent>(onInvoke: (_) {
                  if (_fullscreen) {
                    _toggleFullscreen();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                  return null;
                }),
                _PrevIntent:
                    CallbackAction<_PrevIntent>(onInvoke: (_) {
                  _go(-1);
                  return null;
                }),
                _NextIntent:
                    CallbackAction<_NextIntent>(onInvoke: (_) {
                  _go(1);
                  return null;
                }),
                _Back10Intent: CallbackAction<_Back10Intent>(onInvoke: (_) {
                  _seekBy(-10);
                  return null;
                }),
                _Fwd10Intent: CallbackAction<_Fwd10Intent>(onInvoke: (_) {
                  _seekBy(10);
                  return null;
                }),
              },
              child: Focus(
                autofocus: true,
                child: MouseRegion(
                  onHover: (_) => _bumpControls(),
                  child: LayoutBuilder(builder: (context, box) {
                    return Stack(fit: StackFit.expand, children: [
                      const ColoredBox(color: Colors.black),
                      _surface(),
                      // Gesture layer BELOW the controls: single tap toggles
                      // controls, double-tap left/right seeks ∓10s. Kept off the
                      // controls so buttons stay instant (no double-tap delay).
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _controls = !_controls),
                          onDoubleTapDown: (d) => _onDoubleTapZone(d, box.maxWidth),
                          onDoubleTap: () {}, // enables double-tap recognition
                        ),
                      ),
                      if (_showSpinner) _buffering(c),
                      if (_phase == _Phase.error) _error(c),
                      if (_seekFlash != 0) _seekFlashOverlay(c, box.maxWidth),
                      _overlay(c),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ));
      }),
    );
  }

  Widget _surface() {
    final svc = _svc;
    if (svc is VideoPlayerPlaybackService) {
      final ctrl = svc.controller;
      if (ctrl != null && ctrl.value.isInitialized && !_switching) {
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
          Text(
            _phase == _Phase.switchingSource
                ? '${context.tr('preparing')} · ${_item.title}'
                : context.tr(_item.live ? 'preparing' : 'loading'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: Colors.white70),
          ),
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
              AbkButton(context.tr('retry'),
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    setState(() => _switching = true);
                    _open();
                  }),
              const SizedBox(width: 12),
              AbkButton(context.tr('back'),
                  kind: AbkButtonKind.ghost,
                  onPressed: () => Navigator.of(context).maybePop()),
            ]),
          ]),
        ),
      );

  Widget _seekFlashOverlay(dynamic c, double width) {
    final left = _seekFlash < 0;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(left ? Icons.replay_10_rounded : Icons.forward_10_rounded,
                    color: Colors.white, size: 30),
                Text(left ? '-10s' : '+10s',
                    style: context.type.metadata.copyWith(color: Colors.white)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(dynamic c) {
    final now = _epg.isNotEmpty ? _epg[0].title : null;
    final next = _epg.length > 1 ? _epg[1].title : null;
    return AnimatedOpacity(
      opacity: _controls ? 1 : 0,
      duration: _controls ? AbkMotion.searchIn : AbkMotion.overlayOut,
      child: IgnorePointer(
        ignoring: !_controls,
        child: Column(children: [
          // ---- top bar ----
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.cardTitle.copyWith(color: Colors.white)),
                        if (now != null)
                          Text('${context.tr('liveBadge')}: $now',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.caption.copyWith(color: c.accentPrimary))
                        else if (_item.subtitle != null)
                          Text(_item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.caption.copyWith(color: Colors.white70)),
                        if (next != null)
                          Text('› $next',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.caption.copyWith(color: Colors.white54)),
                      ]),
                ),
                if (_item.live)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: c.accentSecondary, borderRadius: AbkRadius.brXs),
                    child: Text(context.tr('liveBadge'),
                        style: context.type.metadata
                            .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          ),
          const Spacer(),
          // ---- centre transport (VOD gets ±10s + play/pause) ----
          if (!_item.live)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _RoundBtn(
                  icon: Icons.replay_10_rounded,
                  onTap: _seekable ? () => _seekBy(-10) : null),
              const SizedBox(width: 28),
              _RoundBtn(
                  icon: _state.status == PlaybackStatus.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 46,
                  onTap: _togglePlay),
              const SizedBox(width: 28),
              _RoundBtn(
                  icon: Icons.forward_10_rounded,
                  onTap: _seekable ? () => _seekBy(10) : null),
            ]),
          const Spacer(),
          // ---- bottom bar ----
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
            ),
            child: SafeArea(
              top: false,
              child: Column(children: [
                if (!_item.live) _progress(c),
                Row(children: [
                  if (widget.items.length > 1) ...[
                    IconButton(
                      onPressed: _hasPrev ? () => _go(-1) : null,
                      tooltip: _item.live
                          ? context.tr('prevChannel')
                          : context.tr('prevEpisode'),
                      icon: Icon(
                          _item.live
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.skip_previous_rounded,
                          color: _hasPrev ? Colors.white : Colors.white30),
                    ),
                    IconButton(
                      onPressed: _hasNext ? () => _go(1) : null,
                      tooltip: _item.live
                          ? context.tr('nextChannel')
                          : context.tr('nextEpisode'),
                      icon: Icon(
                          _item.live
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.skip_next_rounded,
                          color: _hasNext ? Colors.white : Colors.white30),
                    ),
                  ],
                  IconButton(
                    onPressed: _togglePlay,
                    icon: Icon(
                        _state.status == PlaybackStatus.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30),
                  ),
                  if (!_item.live)
                    Text('${_fmt(_displayPos())} / ${_fmt(_state.duration)}',
                        style: context.type.playerControl.copyWith(color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: Icon(
                        _fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
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

  Duration _displayPos() {
    if (_dragging && _state.duration > Duration.zero) {
      return _state.duration * _dragValue;
    }
    return _state.position;
  }

  Widget _progress(dynamic c) {
    final durMs = _state.duration.inMilliseconds;
    final posMs = _state.position.inMilliseconds;
    final value =
        _dragging ? _dragValue : (durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: c.accentPrimary,
        inactiveTrackColor: Colors.white24,
        thumbColor: c.accentPrimary,
        overlayColor: c.accentPrimary.withValues(alpha: 0.2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      child: Slider(
        value: value,
        // Continuous scrub: update a local target while dragging (cheap, no
        // decoder work), and issue exactly one real seek on release.
        onChangeStart: durMs > 0
            ? (v) {
                setState(() {
                  _dragging = true;
                  _dragValue = v;
                });
                _hide?.cancel();
              }
            : null,
        onChanged: durMs > 0 ? (v) => setState(() => _dragValue = v) : null,
        onChangeEnd: durMs > 0
            ? (v) {
                _svc.seek(Duration(milliseconds: (v * durMs).round()));
                setState(() => _dragging = false);
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

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const _RoundBtn({required this.icon, this.onTap, this.size = 34});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? 0.04 : 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon,
              color: onTap == null ? Colors.white30 : Colors.white, size: size),
        ),
      ),
    );
  }
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _SelectIntent extends Intent {
  const _SelectIntent();
}

class _FsIntent extends Intent {
  const _FsIntent();
}

class _EscIntent extends Intent {
  const _EscIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _Back10Intent extends Intent {
  const _Back10Intent();
}

class _Fwd10Intent extends Intent {
  const _Fwd10Intent();
}
