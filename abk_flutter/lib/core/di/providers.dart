import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/session_local_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/epg/data/datasource.dart';
import '../../features/epg/data/repository_impl.dart';
import '../../features/epg/domain/repository.dart';
import '../../features/epg/domain/usecases.dart';
import '../../features/favorites/favorites_repository.dart';
import '../../features/favorites/parental_lock_repository.dart';
import '../../features/favorites/resume_repository.dart';
import '../../features/live/data/datasource.dart';
import '../../features/live/data/repository_impl.dart';
import '../../features/live/domain/repository.dart';
import '../../features/live/domain/usecases.dart';
import '../../features/movies/data/datasource.dart';
import '../../features/movies/data/repository_impl.dart';
import '../../features/movies/domain/repository.dart';
import '../../features/movies/domain/usecases.dart';
import '../../features/series/data/datasource.dart';
import '../../features/series/data/repository_impl.dart';
import '../../features/series/domain/repository.dart';
import '../../features/series/domain/usecases.dart';
import '../../features/settings/catalogue_cache_meta.dart';
import '../../features/settings/settings_repository.dart';
import '../config/content_api_resolver.dart';
import '../config/remote_config_service.dart';
import '../device/device_envelope.dart';
import '../logging/app_logger.dart';
import '../logging/redaction.dart';
import '../network/content_client.dart';
import '../network/request_builder.dart';
import '../network/runtime_session.dart';
import '../player/playback_service.dart';
import '../player/playback_source_factory.dart';
import '../player/video_player_playback_service.dart';
import '../storage/key_value_store.dart';
import '../storage/secure_store.dart';
import '../network/xor_codec.dart';

// ---- Overridden at bootstrap ------------------------------------------------
final sharedPreferencesProvider = Provider<SharedPreferences>(
    (_) => throw StateError('sharedPreferencesProvider must be overridden'));

final deviceModelProvider = Provider<String>((_) => 'generic');

// ---- Core singletons --------------------------------------------------------
final redactorProvider = Provider<Redactor>((_) => Redactor());

final loggerProvider = Provider<AppLogger>(
    (ref) => AppLogger(redactor: ref.watch(redactorProvider)));

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final xorCodecProvider = Provider<XorCodec>((_) => XorCodec.abk());

final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => FirebaseRestRemoteConfigService(
    client: ref.watch(httpClientProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final contentApiResolverProvider = Provider<ContentApiResolver>(
  (ref) => ContentApiResolver(
    remoteConfig: ref.watch(remoteConfigServiceProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final keyValueStoreProvider = Provider<KeyValueStore>(
    (ref) => SharedPrefsKeyValueStore(ref.watch(sharedPreferencesProvider)));

// macOS: avoid the Keychain entirely (it prompts for the system password on
// every rebuild of a locally-signed app). The App Sandbox container is private
// to this app, so a file store there needs no Keychain and never prompts.
// iOS/Android keep flutter_secure_storage, which does not have this problem.
final secureStoreProvider = Provider<SecureStore>(
    (_) => Platform.isMacOS ? MacOsFileSecureStore() : FlutterSecureStore());

final runtimeSessionProvider = Provider<RuntimeSession>((_) => RuntimeSession());

/// Synchronous device envelope: a stable id is persisted in prefs (sync API).
final deviceEnvelopeProvider = Provider<DeviceEnvelope>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final model = ref.watch(deviceModelProvider);
  const key = 'device_stable_id';
  var id = prefs.getString(key);
  if (id == null || id.isEmpty) {
    final r = Random.secure();
    id = List<String>.generate(
      6,
      (i) => (i == 0 ? 0x02 : r.nextInt(256)).toRadixString(16).padLeft(2, '0'),
    ).join(':');
    prefs.setString(key, id);
  }
  return DeviceEnvelope(mac: id, sn: id, model: model.isEmpty ? 'generic' : model);
});

final contentRequestBuilderProvider = Provider<ContentRequestBuilder>(
  (ref) => ContentRequestBuilder(
    credentials: ref.watch(runtimeSessionProvider),
    device: ref.watch(deviceEnvelopeProvider),
  ),
);

final contentClientProvider = Provider<ContentClient>(
  (ref) => ContentClient(
    httpClient: ref.watch(httpClientProvider),
    codec: ref.watch(xorCodecProvider),
    resolver: ref.watch(contentApiResolverProvider),
    logger: ref.watch(loggerProvider),
  ),
);

// ---- Auth -------------------------------------------------------------------
final _authRemoteProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(
    client: ref.watch(contentClientProvider),
    builder: ref.watch(contentRequestBuilderProvider),
  ),
);

final _sessionLocalProvider = Provider<SessionLocalDataSource>(
    (ref) => SessionLocalDataSource(ref.watch(secureStoreProvider)));

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(_authRemoteProvider),
    local: ref.watch(_sessionLocalProvider),
    redactor: ref.watch(redactorProvider),
  ),
);

final sessionControllerProvider =
    StateNotifierProvider<SessionController, AuthState>(
  (ref) => SessionController(
    loginUseCase: LoginUseCase(ref.watch(authRepositoryProvider)),
    logoutUseCase: LogoutUseCase(ref.watch(authRepositoryProvider)),
    restoreUseCase: RestoreSessionUseCase(ref.watch(authRepositoryProvider)),
    session: ref.watch(runtimeSessionProvider),
  ),
);

// ---- Live -------------------------------------------------------------------
final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => LiveRepositoryImpl(LiveRemoteDataSource(
    client: ref.watch(contentClientProvider),
    builder: ref.watch(contentRequestBuilderProvider),
  )),
);
final getLiveCategoriesProvider =
    Provider((ref) => GetLiveCategories(ref.watch(liveRepositoryProvider)));
final getLiveChannelsProvider =
    Provider((ref) => GetLiveChannels(ref.watch(liveRepositoryProvider)));
final resolveLiveStreamUrlProvider =
    Provider((ref) => ResolveLiveStreamUrl(ref.watch(runtimeSessionProvider)));

// ---- Movies -----------------------------------------------------------------
final movieRepositoryProvider = Provider<MovieRepository>(
  (ref) => MovieRepositoryImpl(MovieRemoteDataSource(
    client: ref.watch(contentClientProvider),
    builder: ref.watch(contentRequestBuilderProvider),
  )),
);
final getMovieCategoriesProvider =
    Provider((ref) => GetMovieCategories(ref.watch(movieRepositoryProvider)));
final getMoviesProvider =
    Provider((ref) => GetMovies(ref.watch(movieRepositoryProvider)));
final getMovieInfoProvider =
    Provider((ref) => GetMovieInfo(ref.watch(movieRepositoryProvider)));
final selectMovieQualityProvider = Provider((_) => SelectMovieQuality());

// ---- Series -----------------------------------------------------------------
final seriesRepositoryProvider = Provider<SeriesRepository>(
  (ref) => SeriesRepositoryImpl(SeriesRemoteDataSource(
    client: ref.watch(contentClientProvider),
    builder: ref.watch(contentRequestBuilderProvider),
  )),
);
final getSeriesCategoriesProvider =
    Provider((ref) => GetSeriesCategories(ref.watch(seriesRepositoryProvider)));
final getSeriesProvider =
    Provider((ref) => GetSeries(ref.watch(seriesRepositoryProvider)));
final getSeriesInfoProvider =
    Provider((ref) => GetSeriesInfo(ref.watch(seriesRepositoryProvider)));
final resolveEpisodeUrlProvider = Provider((_) => ResolveEpisodeUrl());

// ---- EPG --------------------------------------------------------------------
final epgRepositoryProvider = Provider<EpgRepository>(
  (ref) => EpgRepositoryImpl(EpgRemoteDataSource(
    httpClient: ref.watch(httpClientProvider),
    session: ref.watch(runtimeSessionProvider),
    logger: ref.watch(loggerProvider),
  )),
);
final getShortEpgProvider =
    Provider((ref) => GetShortEpg(ref.watch(epgRepositoryProvider)));

// ---- Local features ---------------------------------------------------------
final favoritesRepositoryProvider =
    Provider((ref) => FavoritesRepository(ref.watch(keyValueStoreProvider)));
final resumeRepositoryProvider =
    Provider((ref) => ResumeRepository(ref.watch(keyValueStoreProvider)));
final parentalLockRepositoryProvider = Provider((ref) => ParentalLockRepository(
      secure: ref.watch(secureStoreProvider),
      store: ref.watch(keyValueStoreProvider),
    ));
final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(keyValueStoreProvider)));
final catalogueCacheMetaProvider =
    Provider((ref) => CatalogueCacheMeta(ref.watch(keyValueStoreProvider)));

// ---- Player -----------------------------------------------------------------
final playbackServiceProvider = Provider<PlaybackService>((ref) {
  final s = VideoPlayerPlaybackService();
  ref.onDispose(s.dispose);
  return s;
});
final playbackSourceFactoryProvider =
    Provider((ref) => PlaybackSourceFactory(ref.watch(runtimeSessionProvider)));
