import 'dart:async';

import 'package:abk_player/core/design/breakpoints.dart';
import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/i18n/strings.dart';
import 'package:abk_player/core/network/runtime_session.dart';
import 'package:abk_player/core/player/playback_service.dart';
import 'package:abk_player/core/player/playback_source_factory.dart';
import 'package:abk_player/core/storage/key_value_store.dart';
import 'package:abk_player/features/player/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drivable fake — records calls and emits states, no platform controller.
class FakeService implements PlaybackService {
  final _ctrl = StreamController<PlaybackState>.broadcast();
  PlaybackState _s = PlaybackState.idle;
  int loads = 0, plays = 0, pauses = 0, stops = 0;
  Duration? lastSeek;
  final List<String> loadedUrls = [];
  final Duration vodDuration;

  FakeService({this.vodDuration = const Duration(minutes: 10)});

  @override
  PlaybackState get state => _s;
  @override
  Stream<PlaybackState> get stateStream => _ctrl.stream;

  @override
  Future<void> load(PlaybackSource source) async {
    loads++;
    loadedUrls.add(source.url);
    _emit(PlaybackState(status: PlaybackStatus.buffering, duration: vodDuration));
  }

  @override
  Future<void> play() async {
    plays++;
    _emit(PlaybackState(status: PlaybackStatus.playing, duration: vodDuration, position: _s.position));
  }

  @override
  Future<void> pause() async {
    pauses++;
    _emit(PlaybackState(status: PlaybackStatus.paused, duration: vodDuration, position: _s.position));
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _emit(PlaybackState(status: _s.status, duration: vodDuration, position: position));
  }

  @override
  Future<void> stop() async {
    stops++;
    _emit(PlaybackState.idle);
  }

  @override
  Future<void> dispose() async {
    if (!_ctrl.isClosed) await _ctrl.close();
  }

  void _emit(PlaybackState s) {
    _s = s;
    if (!_ctrl.isClosed) _ctrl.add(s);
  }
}

PlaybackItem _ep(String id) => PlaybackItem(
    url: 'http://h/$id', title: 'Ep $id', resumeId: id, kind: 'episode');
PlaybackItem _live(String id) => PlaybackItem(
    url: 'http://h/$id', title: 'Ch $id', live: true, streamId: 1);

Widget _app(FakeService svc, List<PlaybackItem> items, {int index = 0}) => ProviderScope(
      overrides: [
        playbackServiceProvider.overrideWithValue(svc),
        playbackSourceFactoryProvider.overrideWithValue(PlaybackSourceFactory(RuntimeSession())),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      child: MaterialApp(
        theme: AbkTheme.dark(),
        darkTheme: AbkTheme.dark(),
        supportedLocales: AbkStrings.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('en'),
        // Directional navigation, like the real app on TV.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(navigationMode: NavigationMode.directional),
          child: child!,
        ),
        home: PlayerScreen(items: items, index: index),
      ),
    );

/// Pump enough frames for the async post-frame _open() to reach `playing`,
/// without pumpAndSettle (which would hang on the periodic save timer).
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}

double _controlsOpacity(WidgetTester t) =>
    t.widget<AnimatedOpacity>(find.byKey(const Key('player_controls'))).opacity;

FocusNode _timelineNode(WidgetTester t) => t
    .widgetList<Focus>(find.descendant(
        of: find.byKey(const Key('player_timeline')),
        matching: find.byType(Focus)))
    .first
    .focusNode!;

void main() {
  tearDown(() => AbkBreakpoints.isTv = false);

  Future<void> tvSurface(WidgetTester t) async {
    AbkBreakpoints.isTv = true;
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(1920, 1080);
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  testWidgets('TV: Play/Pause is a real focusable control — SELECT toggles it', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    // Playback is running; initial focus lands on Play/Pause (not on nothing).
    expect(svc.plays, greaterThanOrEqualTo(1));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // D-pad SELECT on the focused Play/Pause toggles playback (no global OK
    // shortcut needed — the button itself is the focus target that activates).
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(svc.pauses, greaterThanOrEqualTo(1), reason: 'focused Play/Pause pauses on SELECT');

    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(svc.plays, greaterThanOrEqualTo(2), reason: 'SELECT again resumes');
  });

  testWidgets('TV: progress bar is a focusable timeline — RIGHT scrubs, UP leaves', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    // The VOD progress bar is a first-class focus target on TV.
    expect(find.byKey(const Key('player_timeline')), findsOneWidget);

    _timelineNode(t).requestFocus();
    await t.pump();
    expect(_timelineNode(t).hasFocus, isTrue);

    // RIGHT nudges the seek target; the real seek is debounced, then issued.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump(const Duration(milliseconds: 400));
    expect(svc.lastSeek, isNotNull, reason: 'RIGHT on the focused timeline seeks');
    expect(svc.lastSeek!.inSeconds, greaterThan(0), reason: 'forward scrub');

    // UP leaves the timeline sub-mode (focus moves off the bar).
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(_timelineNode(t).hasFocus, isFalse, reason: 'UP releases the timeline');
  });

  testWidgets('TV: repeated RIGHT accumulates before the debounced seek', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    _timelineNode(t).requestFocus();
    await t.pump();

    // Two quick presses within the debounce window → one seek of ~20s (not 10).
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump(const Duration(milliseconds: 60));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump(const Duration(milliseconds: 400));
    expect(svc.lastSeek, isNotNull);
    expect(svc.lastSeek!.inSeconds, 20, reason: 'both presses fold into one seek');
  });

  testWidgets('TV: Prev/Next + ±10s are focusable controls; no floating centre transport', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a'), _ep('b'), _ep('c')], index: 1));
    await _settle(t);

    // Episode Prev/Next are on-screen focus targets.
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    // ±10s are real controls in the bar (one each — the floating centre
    // transport is suppressed on TV so the D-pad path stays linear).
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
  });

  testWidgets('TV live: channel up/down are focusable; no timeline (not seekable)', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_live('101'), _live('102')]));
    await _settle(t);

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    // Live is not a scrub surface — no focusable timeline is exposed.
    expect(find.byKey(const Key('player_timeline')), findsNothing);
  });

  testWidgets('TV: controls auto-hide when idle and a D-pad press re-reveals them', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);
    expect(_controlsOpacity(t), 1);

    // Idle past the 4s auto-hide window → controls hide (PLAYER_VIEW_MODE).
    await t.pump(const Duration(seconds: 5));
    await t.pump();
    expect(_controlsOpacity(t), 0, reason: 'controls fade out when idle');

    // A D-pad press re-reveals the surface (→ CONTROLS_FOCUSED_MODE).
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(_controlsOpacity(t), 1, reason: 'D-pad wakes the control surface');
  });

  testWidgets('TV: navigating with the D-pad keeps controls alive (no mid-nav hide)', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a'), _ep('b')]));
    await _settle(t);

    // Keep pressing D-pad keys around the 4s window; each press resets the timer.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump(const Duration(seconds: 3));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump(const Duration(seconds: 3));
    expect(_controlsOpacity(t), 1, reason: 'controls do not hide while being navigated');
  });

  testWidgets('TV: focus memory — auto-hide then re-show RESTORES the last control', (t) async {
    await tvSurface(t);
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    // Move focus to a NON-default control (the timeline), not Play/Pause.
    _timelineNode(t).requestFocus();
    await t.pump();
    expect(_timelineNode(t).hasFocus, isTrue);

    // Idle past the auto-hide window → controls hide (focus remembered).
    await t.pump(const Duration(seconds: 5));
    await t.pump();
    expect(_controlsOpacity(t), 0);

    // Re-reveal → focus must RESTORE to the timeline, not reset to Play/Pause.
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(_controlsOpacity(t), 1);
    expect(_timelineNode(t).hasFocus, isTrue,
        reason: 'last-focused control (timeline) is restored, not reset to Play/Pause');
  });

  testWidgets('non-TV regression: centre transport + drag Slider, no TV timeline', (t) async {
    AbkBreakpoints.isTv = false;
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    // Touch/desktop keeps the big centred transport and the drag Slider.
    expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    // The TV-only focusable timeline is absent off-TV.
    expect(find.byKey(const Key('player_timeline')), findsNothing);
  });
}
