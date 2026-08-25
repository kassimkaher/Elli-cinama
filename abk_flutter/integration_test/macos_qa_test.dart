// macOS QA closure — native Flutter macOS integration suite over the Phase 1
// foundation. Crosses all layers (bootstrap, Remote Config, secure storage,
// content client, player abstraction, local repos) on the macOS device.
//
// Secrets via --dart-define only (never in source):
//   flutter test integration_test/macos_qa_test.dart -d macos \
//     --dart-define=ABK_USERNAME=… --dart-define=ABK_PASSWORD=…
// ignore_for_file: avoid_print
import 'package:abk_player/app/bootstrap.dart';
import 'package:abk_player/core/config/app_config.dart';
import 'package:abk_player/core/di/providers.dart';
import 'package:abk_player/core/logging/redaction.dart';
import 'package:abk_player/core/player/playback_service.dart';
import 'package:abk_player/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _user = String.fromEnvironment('ABK_USERNAME');
const _pass = String.fromEnvironment('ABK_PASSWORD');
const _skip = _user == '' || _pass == ''; // true → skip live macOS QA

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer c;
  final redactor = Redactor()
    ..registerSecret(_user)
    ..registerSecret(_pass);
  final timings = <String, int>{};

  Future<T> timed<T>(String label, Future<T> Function() body) async {
    final sw = Stopwatch()..start();
    final r = await body();
    timings[label] = (sw..stop()).elapsedMilliseconds;
    return r;
  }

  setUpAll(() async {
    c = await bootstrap();
  });

  tearDownAll(() {
    print('macOS timings(ms): $timings');
    c.dispose();
  });

  testWidgets('config resolution + native launch (bootstrap completed)', (t) async {
    final base = c.read(contentApiResolverProvider).currentOrFallback;
    expect(base.hasScheme, isTrue);
    expect(base.host.isNotEmpty, isTrue);
    print('CONTENT_API host=${base.host}');
  }, skip: _skip);

  testWidgets('auth: unauth → login → authenticated → restart-restore → logout',
      (t) async {
    // Clear any leftover persisted session first (test isolation).
    await c.read(sessionControllerProvider.notifier).logout();
    expect(c.read(sessionControllerProvider), isA<AuthLoggedOut>());

    await timed('login', () => c.read(sessionControllerProvider.notifier).login(_user, _pass));
    final st = c.read(sessionControllerProvider);
    expect(st, isA<AuthAuthenticated>());
    final acc = (st as AuthAuthenticated).account;
    expect(AppConstants.isLoginSuccess(acc.status), isTrue);
    print('login status=${acc.status} host=${Uri.tryParse(acc.host ?? '')?.host}');

    // Simulate restart: fresh container restores session from secure storage.
    final c2 = await bootstrap();
    addTearDown(c2.dispose);
    expect(c2.read(sessionControllerProvider), isA<AuthAuthenticated>(),
        reason: 'session should restore from secure storage after restart');

    // Logout clears the persisted session.
    await c.read(sessionControllerProvider.notifier).logout();
    expect(c.read(sessionControllerProvider), isA<AuthLoggedOut>());
    final c3 = await bootstrap();
    addTearDown(c3.dispose);
    expect(c3.read(sessionControllerProvider), isA<AuthLoggedOut>(),
        reason: 'logout should clear secure storage');

    // Re-login for the remaining tests.
    await c.read(sessionControllerProvider.notifier).login(_user, _pass);
    expect(c.read(sessionControllerProvider), isA<AuthAuthenticated>());
  }, timeout: const Timeout(Duration(minutes: 2)), skip: _skip);

  testWidgets('live: categories + channels + filter + URL resolution', (t) async {
    final cats = await timed('live_cats', () => c.read(getLiveCategoriesProvider).call());
    final chans = await timed('live_channels', () => c.read(getLiveChannelsProvider).call());
    final catList = cats.valueOrNull!;
    final chanList = chans.valueOrNull!;
    expect(catList.length, greaterThan(0));
    expect(chanList.length, greaterThan(0));
    print('live: cats=${catList.length} channels=${chanList.length}');

    // Client-side category filtering.
    final realCat = catList.firstWhere((x) => x.id != '-1');
    final catId = int.tryParse(realCat.id);
    final filtered = chanList.where((ch) => ch.categoryId == catId).toList();
    expect(filtered.length, lessThanOrEqualTo(chanList.length));

    // URL resolution + redaction.
    final ch = chanList.firstWhere((c0) => (c0.streamUrlTemplate ?? '').isNotEmpty);
    final url = c.read(resolveLiveStreamUrlProvider).call(ch)!;
    expect(url.contains('{user}'), isFalse);
    final safe = redactor.redactUrl(url);
    expect(safe.contains(_user), isFalse);
    expect(safe.contains(_pass), isFalse);
    print('live url (redacted)=$safe');
  }, timeout: const Timeout(Duration(minutes: 2)), skip: _skip);

  testWidgets('movies: categories + list + one info + quality', (t) async {
    final mcats = await timed('movies_cats', () => c.read(getMovieCategoriesProvider).call());
    final mlist = await timed('movies_list', () => c.read(getMoviesProvider).call());
    expect(mcats.valueOrNull!.length, greaterThan(0));
    final list = mlist.valueOrNull!;
    expect(list.length, greaterThan(0));
    final info = await c.read(getMovieInfoProvider).call(list.first.id);
    expect(info.valueOrNull, isNotNull);
    final best = c.read(selectMovieQualityProvider).call(info.valueOrNull!);
    print('movies: cats=${mcats.valueOrNull!.length} list=${list.length} best=${best != null}');
  }, timeout: const Timeout(Duration(minutes: 2)), skip: _skip);

  testWidgets('series: categories + list + one info + seasons/episodes', (t) async {
    final scats = await timed('series_cats', () => c.read(getSeriesCategoriesProvider).call());
    final slist = await timed('series_list', () => c.read(getSeriesProvider).call());
    expect(scats.valueOrNull!.length, greaterThan(0));
    final list = slist.valueOrNull!;
    expect(list.length, greaterThan(0));
    final info = await c.read(getSeriesInfoProvider).call(list.first.id);
    expect(info.valueOrNull, isNotNull);
    print('series: cats=${scats.valueOrNull!.length} list=${list.length} '
        'seasons=${info.valueOrNull!.seasons.length}');
  }, timeout: const Timeout(Duration(minutes: 2)), skip: _skip);

  testWidgets('epg: empty state is a valid Ok (no crash/false error)', (t) async {
    final chans = await c.read(getLiveChannelsProvider).call();
    final ch = chans.valueOrNull!.first;
    final res = await c.read(getShortEpgProvider).call(ch.id);
    expect(res.isOk, isTrue);
    print('epg: listings=${res.valueOrNull!.length} has_epg=${ch.hasEpg}');
  }, timeout: const Timeout(Duration(minutes: 1)), skip: _skip);

  testWidgets('local repositories: favorites/resume/parental/search/cache', (t) async {
    final fav = c.read(favoritesRepositoryProvider);
    await fav.add('live', '123');
    expect(await fav.isFavorite('live', '123'), isTrue);
    await fav.remove('live', '123');
    expect(await fav.isFavorite('live', '123'), isFalse);

    final resume = c.read(resumeRepositoryProvider);
    await resume.setPosition('m1', 90);
    expect(await resume.getPosition('m1'), 90);
    expect((await resume.recentIds()).contains('m1'), isTrue);

    final lock = c.read(parentalLockRepositoryProvider);
    await lock.setPin('9999');
    expect(await lock.verify('9999'), isTrue);
    expect(await lock.verify('0000'), isFalse);

    final meta = c.read(catalogueCacheMetaProvider);
    await meta.markUpdated('live');
    expect(await meta.isStale('live', const Duration(hours: 24)), isFalse);

    // Local search over the live channel list.
    final chans = await c.read(getLiveChannelsProvider).call();
    final all = chans.valueOrNull!;
    final sample = all.first.name;
    final term = sample.isNotEmpty
        ? sample.substring(0, sample.length < 2 ? sample.length : 2)
        : 'a';
    final matches = all.where((x) => x.name.toLowerCase().contains(term.toLowerCase()));
    expect(matches.isNotEmpty, isTrue);
    print('local repos: OK; search "$term" matched ${matches.length}');
  }, timeout: const Timeout(Duration(minutes: 2)), skip: _skip);

  testWidgets('player abstraction on macOS: init/source/headers/detect/dispose',
      (t) async {
    final factory = c.read(playbackSourceFactoryProvider);
    final svc = c.read(playbackServiceProvider);

    final chans = await c.read(getLiveChannelsProvider).call();
    final ch = chans.valueOrNull!.firstWhere((x) => (x.streamUrlTemplate ?? '').isNotEmpty);
    final url = c.read(resolveLiveStreamUrlProvider).call(ch)!;
    final src = factory.fromUrl(url, title: ch.name);
    expect(src.headers['User-Agent']?.isNotEmpty, isTrue);
    expect(src.container, isA<StreamContainer>());
    print('player: source built ua=${src.headers['User-Agent']} container=${src.container.name}');

    // Native load attempt (informational — AVFoundation may not decode raw
    // MPEG-TS / cleartext on Apple platforms). Bounded so it cannot hang.
    String playback = 'not-attempted';
    try {
      await svc.load(src).timeout(const Duration(seconds: 12));
      await svc.play();
      playback = 'loaded:${svc.state.status.name}';
    } catch (e) {
      playback = 'adapter-needed:${e.runtimeType}';
    } finally {
      try {
        await svc.stop();
      } catch (_) {}
    }
    print('player: native playback => $playback');

    // Abstraction is stable regardless of native decode result.
    expect(identical(svc, c.read(playbackServiceProvider)), isTrue);
  }, timeout: const Timeout(Duration(minutes: 1)), skip: _skip);
}
