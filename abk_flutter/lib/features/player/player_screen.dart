import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../core/player/playback_service.dart';
import '../../core/player/video_player_playback_service.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/focusable.dart';
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

  /// Android TV / Google TV: controls become a real, D-pad-focusable surface
  /// (focus ring, SELECT activates, focusable progress bar). Off-TV keeps the
  /// touch/mouse behaviour (tap, double-tap seek, drag scrub) untouched.
  bool get _tv => AbkBreakpoints.isTv;
  // On TV, focus lands on Play/Pause whenever the controls are (re)shown.
  final FocusNode _playPauseFocus = FocusNode(debugLabel: 'player.playPause');
  // Holds focus while the controls are hidden so the next D-pad press is caught
  // and re-reveals the surface (PLAYER_VIEW_MODE → CONTROLS_FOCUSED_MODE).
  final FocusNode _rootFocus = FocusNode(debugLabel: 'player.root');
  // True while the focusable progress bar is the focused control (the timeline
  // sub-mode), so BACK returns to the controls instead of hiding them.
  bool _timelineFocused = false;
  // Player-session-local focus memory: the control focused just before an
  // auto-hide, restored when controls re-appear (no reset to Play/Pause).
  FocusNode? _lastFocusedControl;

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
        // TV: controls start visible → land initial focus on Play/Pause so the
        // remote user begins on a real control (never on empty space).
        if (_tv) _playPauseFocus.requestFocus();
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
    final wasHidden = !_controls;
    setState(() => _controls = true);
    // On TV, when the surface is (re)shown, RESTORE the control the user was last
    // on (focus memory) instead of resetting to Play/Pause — unless it no longer
    // exists (then fall back to Play/Pause, e.g. first presentation).
    if (_tv && wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controls) return;
        final last = _lastFocusedControl;
        if (last != null && last.canRequestFocus && last.context != null) {
          last.requestFocus();
        } else {
          _playPauseFocus.requestFocus();
        }
      });
    }
    _restartHideTimer();
  }

  /// (Re)arm the auto-hide. On TV the surface must NOT vanish while the user is
  /// actively navigating it, so any key resets this (see the root key handler);
  /// it also never hides mid-drag.
  void _restartHideTimer() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && !_dragging) _hideControls();
    });
  }

  /// Hide the control surface. On TV, park focus on the invisible root node so
  /// the next D-pad press is caught and re-reveals the controls — after
  /// remembering the control the user was on so it can be restored.
  void _hideControls() {
    _hide?.cancel();
    if (_tv) {
      final pf = FocusManager.instance.primaryFocus;
      if (pf != null && pf != _rootFocus && pf.context != null) {
        _lastFocusedControl = pf;
      }
    }
    setState(() => _controls = false);
    if (_tv) _rootFocus.requestFocus();
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
    _playPauseFocus.dispose();
    _rootFocus.dispose();
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
          // Deterministic BACK hierarchy:
          //   fullscreen        → leave fullscreen
          //   timeline sub-mode → return to the control layer (Play/Pause)
          //   controls visible  → hide the controls
          //   otherwise         → leave the player
          canPop: !_controls && !_fullscreen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_fullscreen) {
              _toggleFullscreen();
            } else if (_tv && _timelineFocused) {
              _playPauseFocus.requestFocus();
              _bumpControls();
            } else if (_controls) {
              _hideControls();
            }
          },
          child: Scaffold(
          backgroundColor: Colors.black,
          body: Shortcuts(
            shortcuts: _shortcuts(),
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
                focusNode: _rootFocus,
                // Off-TV a keyboard user gets immediate space/F/Esc; on TV the
                // root stays out of directional traversal but still catches keys
                // (to keep the surface alive / re-reveal it) as an ancestor.
                autofocus: !_tv,
                skipTraversal: _tv,
                onKeyEvent: _onRootKey,
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
                          onTap: () => _controls ? _hideControls() : _bumpControls(),
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

  /// Media/hardware keys work in every mode. On TV the D-pad arrows and OK are
  /// deliberately NOT global shortcuts — they drive focus traversal between the
  /// visible controls (and LEFT/RIGHT scrubbing once the progress bar is
  /// focused). Off-TV the arrows keep their direct seek / channel shortcuts.
  Map<ShortcutActivator, Intent> _shortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.space): const _PlayPauseIntent(),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): const _PlayPauseIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF): const _FsIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const _EscIntent(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): const _PrevIntent(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext): const _NextIntent(),
      if (!_tv) ...{
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _PrevIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _NextIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const _Back10Intent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const _Fwd10Intent(),
        const SingleActivator(LogicalKeyboardKey.select): const _SelectIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const _SelectIntent(),
      },
    };
  }

  // D-pad keys that drive the TV control surface (LogicalKeyboardKey overrides
  // ==, so this can't be a const Set — a plain predicate keeps it simple).
  bool _isDpadKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.arrowUp ||
      k == LogicalKeyboardKey.arrowDown ||
      k == LogicalKeyboardKey.arrowLeft ||
      k == LogicalKeyboardKey.arrowRight ||
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.gameButtonA ||
      k == LogicalKeyboardKey.enter;

  /// Root (ancestor) key handler for TV. When the controls are hidden, the first
  /// D-pad press reveals + enters them (swallowed so it does not also seek/move).
  /// When they are visible, any D-pad key keeps the surface alive and is passed
  /// through so the focused control / directional traversal handles it.
  KeyEventResult _onRootKey(FocusNode node, KeyEvent e) {
    if (!_tv) return KeyEventResult.ignored;
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!_isDpadKey(e.logicalKey)) return KeyEventResult.ignored;
    if (!_controls) {
      _bumpControls(); // show + focus Play/Pause
      return KeyEventResult.handled; // swallow this press
    }
    _restartHideTimer(); // navigating → do not auto-hide
    return KeyEventResult.ignored; // let the focused control / traversal act
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
    final playing = _state.status == PlaybackStatus.playing;
    return AnimatedOpacity(
      key: const Key('player_controls'),
      opacity: _controls ? 1 : 0,
      duration: _controls ? AbkMotion.searchIn : AbkMotion.overlayOut,
      child: IgnorePointer(
        ignoring: !_controls,
        // Hidden (opacity-0) controls must not be D-pad focus targets on TV, or
        // the remote could focus an invisible button. ExcludeFocus drops them
        // from traversal and releases focus while the surface is hidden.
        child: ExcludeFocus(
          excluding: !_controls,
          child: Column(children: [
            _topBar(c),
            const Spacer(),
            // Touch/desktop keep the big centred transport; on TV every control
            // lives in the (focusable) bottom bar so the D-pad path stays linear.
            if (!_tv && !_item.live) _centerTransport(playing),
            const Spacer(),
            _bottomBar(c, playing),
          ]),
        ),
      ),
    );
  }

  // ---- top bar (Back + title + EPG/live) ----
  Widget _topBar(dynamic c) {
    final now = _epg.isNotEmpty ? _epg[0].title : null;
    final next = _epg.length > 1 ? _epg[1].title : null;
    return Container(
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
          _PlayerBtn(
            icon: Icons.arrow_back_rounded,
            tooltip: context.tr('back'),
            onTap: () => Navigator.of(context).maybePop(),
          ),
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
    );
  }

  // ---- centre transport (touch/desktop VOD: big ±10s + play/pause) ----
  Widget _centerTransport(bool playing) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundBtn(
              icon: Icons.replay_10_rounded,
              onTap: _seekable ? () => _seekBy(-10) : null),
          const SizedBox(width: 28),
          _RoundBtn(
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 46,
              onTap: _togglePlay),
          const SizedBox(width: 28),
          _RoundBtn(
              icon: Icons.forward_10_rounded,
              onTap: _seekable ? () => _seekBy(10) : null),
        ],
      );

  // ---- bottom bar (progress + focusable control row) ----
  Widget _bottomBar(dynamic c, bool playing) {
    return Container(
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
          // VOD progress: a first-class focusable timeline on TV (LEFT/RIGHT
          // scrub, UP/DOWN leave), the drag slider for touch/mouse elsewhere.
          if (!_item.live) (_tv ? _tvTimeline(c) : _progress(c)),
          Row(children: _bottomControls(playing)),
        ]),
      ),
    );
  }

  List<Widget> _bottomControls(bool playing) {
    final playPause = _PlayerBtn(
      focusNode: _playPauseFocus,
      icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 30,
      tooltip: context.tr(playing ? 'pause' : 'play'),
      onTap: _togglePlay,
    );
    final row = <Widget>[];
    final hasPlaylist = widget.items.length > 1;

    // On TV, ±10s become real focusable controls (not just remote shortcuts).
    if (_tv && !_item.live) {
      row.add(_PlayerBtn(
          icon: Icons.replay_10_rounded,
          tooltip: '-10s',
          onTap: _seekable ? () => _seekBy(-10) : null));
    }
    if (hasPlaylist) row.add(_channelBtn(prev: true));
    row.add(playPause);
    if (hasPlaylist) row.add(_channelBtn(prev: false));
    if (_tv && !_item.live) {
      row.add(_PlayerBtn(
          icon: Icons.forward_10_rounded,
          tooltip: '+10s',
          onTap: _seekable ? () => _seekBy(10) : null));
    }
    if (!_item.live) {
      row.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('${_fmt(_displayPos())} / ${_fmt(_state.duration)}',
            style: context.type.playerControl.copyWith(color: Colors.white)),
      ));
    }
    row.add(const Spacer());
    row.add(_PlayerBtn(
      icon: _fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
      tooltip: context.tr(_fullscreen ? 'exitFullscreen' : 'fullscreen'),
      onTap: _toggleFullscreen,
    ));
    return row;
  }

  Widget _channelBtn({required bool prev}) {
    final enabled = prev ? _hasPrev : _hasNext;
    final live = _item.live;
    final icon = live
        ? (prev
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded)
        : (prev ? Icons.skip_previous_rounded : Icons.skip_next_rounded);
    return _PlayerBtn(
      icon: icon,
      tooltip: live
          ? context.tr(prev ? 'prevChannel' : 'nextChannel')
          : context.tr(prev ? 'prevEpisode' : 'nextEpisode'),
      onTap: enabled ? () => _go(prev ? -1 : 1) : null,
    );
  }

  Widget _tvTimeline(dynamic c) => _TvTimeline(
        key: const Key('player_timeline'),
        position: _state.position,
        duration: _state.duration,
        onSeek: (t) {
          _svc.seek(t);
          _bumpControls();
        },
        onActivity: _restartHideTimer,
        onFocusChanged: (f) => _timelineFocused = f,
      );

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

/// A focusable player control. On TV it is a real D-pad focus target (focus
/// ring + tint, SELECT/OK activates) via [AbkFocusable]; on touch/mouse it still
/// activates on tap. A disabled ([onTap] == null) control is dimmed and, on TV,
/// skipped by focus traversal so unavailable actions are never focus targets.
class _PlayerBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final FocusNode? focusNode;
  final String? tooltip;
  const _PlayerBtn({
    required this.icon,
    this.onTap,
    this.size = 30,
    this.focusNode,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final btn = AbkFocusable(
      onTap: onTap,
      disabled: !enabled,
      focusNode: focusNode,
      radius: AbkRadius.brMd,
      semanticLabel: tooltip,
      builder: (ctx, states) {
        final focused = states.contains(WidgetState.focused);
        final hover = states.contains(WidgetState.hovered);
        return Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: focused
                ? Colors.white.withValues(alpha: 0.22)
                : (hover ? Colors.white.withValues(alpha: 0.10) : Colors.transparent),
            borderRadius: AbkRadius.brMd,
          ),
          child: Icon(icon,
              color: enabled ? Colors.white : Colors.white30, size: size),
        );
      },
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// A first-class, D-pad-focusable progress bar for TV (TIMELINE_FOCUSED_MODE).
/// When focused, LEFT/RIGHT nudge a pending seek target (repeat/hold accelerates
/// naturally via key-repeat), the target time is shown, and the real seek is
/// debounced. UP/DOWN and SELECT bubble so focus can leave the timeline.
class _TvTimeline extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final void Function(Duration target) onSeek;
  final VoidCallback onActivity;
  final ValueChanged<bool> onFocusChanged;
  const _TvTimeline({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onActivity,
    required this.onFocusChanged,
  });

  @override
  State<_TvTimeline> createState() => _TvTimelineState();
}

class _TvTimelineState extends State<_TvTimeline> {
  final FocusNode _node = FocusNode(debugLabel: 'player.timeline');
  bool _focused = false;
  double? _target; // 0..1 pending seek target while adjusting
  Timer? _debounce;

  static const int _stepMs = 10000; // 10s per press

  @override
  void dispose() {
    _debounce?.cancel();
    _node.dispose();
    super.dispose();
  }

  double get _current {
    final d = widget.duration.inMilliseconds;
    if (d <= 0) return 0;
    return (widget.position.inMilliseconds / d).clamp(0.0, 1.0);
  }

  void _nudge(int dir) {
    final d = widget.duration.inMilliseconds;
    if (d <= 0) return;
    final base = _target ?? _current;
    final t = (base + dir * _stepMs / d).clamp(0.0, 1.0);
    setState(() => _target = t);
    widget.onActivity();
    // Debounce the real seek so a burst of presses issues one decode seek.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final tt = _target;
      if (tt != null) widget.onSeek(widget.duration * tt);
      if (mounted) setState(() => _target = null);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _nudge(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      _nudge(1);
      return KeyEventResult.handled;
    }
    // UP/DOWN/SELECT bubble → focus leaves the timeline / acts elsewhere.
    return KeyEventResult.ignored;
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = _target ?? _current;
    final adjusting = _target != null;
    final active = _focused || adjusting;
    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      onFocusChange: (f) {
        setState(() => _focused = f);
        widget.onFocusChanged(f);
        if (f) widget.onActivity();
      },
      child: Semantics(
        slider: true,
        label: 'Seek',
        value: _fmt(widget.duration * v),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Target-time readout floats above the thumb while adjusting/focused.
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Align(
                alignment: Alignment(v * 2 - 1, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: AbkRadius.brXs),
                  child: Text(_fmt(widget.duration * v),
                      style: context.type.metadata.copyWith(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (ctx, box) {
              final w = box.maxWidth;
              final h = active ? 6.0 : 3.0;
              final thumbR = active ? 9.0 : 6.0;
              return SizedBox(
                height: 20,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                        height: h,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(h))),
                    FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(
                          height: h,
                          decoration: BoxDecoration(
                              color: c.accentPrimary,
                              borderRadius: BorderRadius.circular(h))),
                    ),
                    Positioned(
                      left: (v * w - thumbR).clamp(0.0, (w - 2 * thumbR).clamp(0.0, w)),
                      child: Container(
                        width: thumbR * 2,
                        height: thumbR * 2,
                        decoration: BoxDecoration(
                          color: c.accentPrimary,
                          shape: BoxShape.circle,
                          border: active
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          boxShadow: _focused ? AbkElevation.focus : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]),
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
