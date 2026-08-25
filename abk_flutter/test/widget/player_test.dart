import 'dart:async';

import 'package:abk_player/core/design/theme.dart';
import 'package:abk_player/core/i18n/strings.dart';
import 'package:abk_player/core/network/runtime_session.dart';
import 'package:abk_player/core/player/playback_service.dart';
import 'package:abk_player/core/player/playback_source_factory.dart';
import 'package:abk_player/core/storage/key_value_store.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/features/player/player_screen.dart';
import 'package:flutter/material.dart';
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
  bool failNextLoad = false;
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
    if (failNextLoad) {
      failNextLoad = false;
      _emit(const PlaybackState(status: PlaybackStatus.error, errorMessage: 'x'));
      throw StateError('load failed');
    }
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

final _navKey = GlobalKey<NavigatorState>();

Widget _app(FakeService svc, List<PlaybackItem> items, {int index = 0}) => ProviderScope(
      overrides: [
        playbackServiceProvider.overrideWithValue(svc),
        playbackSourceFactoryProvider.overrideWithValue(PlaybackSourceFactory(RuntimeSession())),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      child: MaterialApp(
        navigatorKey: _navKey,
        theme: AbkTheme.dark(),
        darkTheme: AbkTheme.dark(),
        supportedLocales: AbkStrings.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PlayerScreen(items: items, index: index),
      ),
    );

/// Pump enough frames to let the async post-frame _open() reach `playing`,
/// without pumpAndSettle (which would hang on the periodic save timer).
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('stop() releases the controller on leave (no audio leak)', (t) async {
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);
    expect(svc.loads, 1);
    expect(svc.plays, greaterThanOrEqualTo(1));

    // Leave the player (scope stays alive, like a real Navigator.pop).
    _navKey.currentState!.pushReplacement(
        MaterialPageRoute(builder: (_) => const SizedBox()));
    await t.pumpAndSettle();
    expect(svc.stops, greaterThanOrEqualTo(1), reason: 'controller released on leave');
  });

  testWidgets('±10s seek buttons call seek() relative to position', (t) async {
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    await t.tap(find.byIcon(Icons.forward_10_rounded));
    await t.pump();
    expect(svc.lastSeek, const Duration(seconds: 10));

    await t.tap(find.byIcon(Icons.replay_10_rounded));
    await t.pump();
    // position advanced to 10s by the previous seek emit → -10 → 0.
    expect(svc.lastSeek, const Duration(seconds: 0));
  });

  testWidgets('rapid next presses debounce into ONE extra load (surf)', (t) async {
    final svc = FakeService();
    await t.pumpWidget(_app(svc, [_ep('a'), _ep('b'), _ep('c')]));
    await _settle(t);
    expect(svc.loads, 1);

    await t.tap(find.byIcon(Icons.skip_next_rounded));
    await t.pump(const Duration(milliseconds: 80));
    await t.tap(find.byIcon(Icons.skip_next_rounded));
    await t.pump(const Duration(milliseconds: 450)); // debounce fires once
    await _settle(t);

    expect(svc.loads, 2, reason: 'surfing several items issues exactly one load');
    expect(svc.loadedUrls.last, 'http://h/c', reason: 'lands on the final target');
  });

  testWidgets('load failure shows error, retry re-loads', (t) async {
    final svc = FakeService()..failNextLoad = true;
    await t.pumpWidget(_app(svc, [_ep('a')]));
    await _settle(t);

    expect(find.text('Playback failed'), findsOneWidget);
    expect(svc.loads, 1);

    await t.tap(find.text('Retry'));
    await _settle(t);
    expect(svc.loads, 2, reason: 'retry issues a fresh load');
    expect(find.text('Playback failed'), findsNothing);
  });
}
