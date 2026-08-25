import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/images.dart';
import '../../shared/widgets/layout.dart';
import '../catalogue/catalogue_providers.dart';
import '../favorites/playback_history_repository.dart';
import '../live/domain/entities.dart';
import '../live/presentation/live_browser_screen.dart';
import '../movies/domain/entities.dart';
import '../movies/presentation/movie_details_screen.dart';
import '../player/player_screen.dart';
import '../series/domain/entities.dart';
import '../series/presentation/series_details_screen.dart';
import '../settings/parental_gate.dart';
import '../shell/adaptive_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wc = context.wc;
    final m = AbkBreakpoints.contentMargin(wc);
    final gap = AbkBreakpoints.sectionGap(wc);

    return ContentMax(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moviesProvider);
          ref.invalidate(seriesListProvider);
          ref.invalidate(liveCategoriesProvider);
          ref.invalidate(continueWatchingProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(m, AbkSpace.s8, m, AbkSpace.s40),
          children: [
            _Hero(),
            SizedBox(height: gap),
            _ContinueWatching(),
            _FavoriteChannels(),
            _MoviesRail(),
            SizedBox(height: gap),
            _SeriesRail(),
            SizedBox(height: gap),
            _LiveCategories(),
          ],
        ),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredProvider);
    return featured.when(
      loading: () => const AspectRatio(aspectRatio: AbkAspect.backdrop, child: SkeletonBox(radius: AbkRadius.brLg)),
      error: (_, __) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink(); // no hero over flat colour
        return HeroBanner(
          title: m.name,
          meta: [m.year, m.genre, m.rating],
          backdropUrl: m.backdrop ?? m.icon,
          playLabel: context.tr('play'),
          detailsLabel: context.tr('details'),
          onPlay: () => _open(context, m),
          onDetails: () => _open(context, m),
        );
      },
    );
  }

  void _open(BuildContext context, MovieListItem m) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: m)));
}

class _ContinueWatching extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cw = ref.watch(continueWatchingProvider);
    return cw.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader(context.tr('continueWatching')),
              PosterRail(
                height: 180,
                itemCount: list.length,
                itemBuilder: (ctx, i) => ContinueWatchingCard(
                  title: list[i].title,
                  subtitle: list[i].subtitle,
                  imageUrl: list[i].image,
                  progress: list[i].progress,
                  width: 260,
                  onTap: () => _resumeEntry(ctx, ref, list[i]),
                ),
              ),
              SizedBox(height: AbkBreakpoints.sectionGap(context.wc)),
            ]),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Deep-links a Continue-Watching entry back to playback (resume is applied by
/// the player via [PlaybackItem.resumeId]). Falls back to the detail screen if
/// the source can no longer be resolved.
Future<void> _resumeEntry(BuildContext context, WidgetRef ref, PlaybackEntry e) async {
  switch (e.kind) {
    case 'live':
      final id = int.tryParse(e.id);
      final channels = ref.read(liveChannelsProvider).valueOrNull;
      LiveChannel? ch;
      if (id != null && channels != null) {
        for (final c in channels) {
          if (c.id == id) {
            ch = c;
            break;
          }
        }
      }
      if (ch != null) {
        await playChannel(context, ref, ch);
      } else {
        ref.read(shellIndexProvider.notifier).state = 1; // Live tab
      }
      return;
    case 'movie':
      try {
        final movies = ref.read(moviesProvider).valueOrNull;
        String? catId;
        for (final m in (movies ?? const <MovieListItem>[])) {
          if (m.id == e.id) {
            catId = m.categoryId;
            break;
          }
        }
        final mcats = ref.read(movieCategoriesProvider).valueOrNull;
        final catLocked = mcats?.any((c) => c.id == catId && c.isLocked) ?? false;
        final allowed = await ensureUnlocked(context, ref,
            kind: 'movie', id: e.id, categoryLocked: catLocked);
        if (!allowed || !context.mounted) return;
        final info = await ref.read(movieInfoProvider(e.id).future);
        final url = ref.read(selectMovieQualityProvider).call(info);
        if (url == null || url.isEmpty) throw StateError('no url');
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PlayerScreen.single(PlaybackItem(
            url: url,
            title: info.title,
            subtitle: MetadataText.of(info),
            resumeId: e.id,
            kind: 'movie',
            image: e.image,
          )),
        ));
      } catch (_) {
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(
              movie: MovieListItem(id: e.id, name: e.title, icon: e.image)),
        ));
      }
      return;
    case 'episode':
      final seriesId = e.id.split('_').first;
      final epNum = e.id.contains('_') ? e.id.split('_').last : null;
      try {
        final seriesList = ref.read(seriesListProvider).valueOrNull;
        String? catId;
        for (final s in (seriesList ?? const <SeriesListItem>[])) {
          if (s.id == seriesId) {
            catId = s.categoryId;
            break;
          }
        }
        final scats = ref.read(seriesCategoriesProvider).valueOrNull;
        final catLocked = scats?.any((c) => c.id == catId && c.isLocked) ?? false;
        final allowed = await ensureUnlocked(context, ref,
            kind: 'series', id: seriesId, categoryLocked: catLocked);
        if (!allowed || !context.mounted) return;
        final d = await ref.read(seriesInfoProvider(seriesId).future);
        var eps = const <Episode>[];
        for (final s in d.seasons) {
          if (s.episodes.any((ep) => ep.episodeNum == epNum)) {
            eps = s.episodes;
            break;
          }
        }
        if (eps.isEmpty && d.seasons.isNotEmpty) eps = d.seasons.first.episodes;
        final playableEps =
            eps.where((ep) => (ep.streamUrl ?? '').isNotEmpty).toList();
        if (playableEps.isEmpty) throw StateError('no episodes');
        final title = d.info?.title ?? e.title;
        if (!context.mounted) return;
        final items = playableEps
            .map((ep) => PlaybackItem(
                  url: ep.streamUrl!,
                  title: '$title · ${ep.episodeName ?? ''}'.trim(),
                  subtitle: ep.episodeNum != null
                      ? '${context.tr('episode')} ${ep.episodeNum}'
                      : null,
                  resumeId: '${seriesId}_${ep.episodeNum}',
                  kind: 'episode',
                  image: e.image,
                ))
            .toList();
        var idx = playableEps.indexWhere((ep) => ep.episodeNum == epNum);
        if (idx < 0) idx = 0;
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerScreen(items: items, index: idx)));
      } catch (_) {
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SeriesDetailsScreen(
              series: SeriesListItem(id: seriesId, title: e.title, icon: e.image)),
        ));
      }
      return;
  }
}

class _FavoriteChannels extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoriteChannelsProvider);
    return favs.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader(context.tr('myFavoriteChannels')),
              PosterRail(
                height: 92,
                itemCount: list.length,
                itemBuilder: (ctx, i) => SizedBox(
                  width: 92,
                  child: GestureDetector(
                    onTap: () => playChannel(ctx, ref, list[i]),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: ctx.c.surfaceStrong, borderRadius: AbkRadius.brMd),
                      child: AbkImage(url: list[i].icon, fit: BoxFit.contain, fallback: LogoFallback(list[i].name)),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AbkBreakpoints.sectionGap(context.wc)),
            ]),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MoviesRail extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider);
    return _Rail(
      title: context.tr('movies'),
      onMore: () => ref.read(shellIndexProvider.notifier).state = 2,
      child: SectionAsync(
        value: movies.whenData((l) => l.take(18).toList()),
        skeleton: _railSkeleton(),
        onRetry: () => ref.invalidate(moviesProvider),
        data: (list) => PosterRail(
          height: 230,
          itemCount: list.length,
          itemBuilder: (ctx, i) => PosterCard(
            title: list[i].name, imageUrl: list[i].icon, rating: list[i].rating,
            meta: [list[i].year], width: AbkBreakpoints.posterWidth(ctx.wc),
            onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: list[i]))),
          ),
        ),
      ),
    );
  }
}

class _SeriesRail extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesListProvider);
    return _Rail(
      title: context.tr('series'),
      onMore: () => ref.read(shellIndexProvider.notifier).state = 3,
      child: SectionAsync(
        value: series.whenData((l) => l.take(18).toList()),
        skeleton: _railSkeleton(),
        onRetry: () => ref.invalidate(seriesListProvider),
        data: (list) => PosterRail(
          height: 230,
          itemCount: list.length,
          itemBuilder: (ctx, i) => PosterCard(
            title: list[i].title, imageUrl: list[i].icon, rating: list[i].rating,
            meta: [list[i].genre], width: AbkBreakpoints.posterWidth(ctx.wc),
            onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: list[i]))),
          ),
        ),
      ),
    );
  }
}

class _LiveCategories extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(liveCategoriesProvider);
    return _Rail(
      title: context.tr('live'),
      onMore: () => ref.read(shellIndexProvider.notifier).state = 1,
      child: SectionAsync(
        value: cats.whenData((l) => l.where((c) => c.id != '-1').take(12).toList()),
        skeleton: _railSkeleton(height: 110),
        onRetry: () => ref.invalidate(liveCategoriesProvider),
        data: (list) => PosterRail(
          height: 110,
          itemCount: list.length,
          itemBuilder: (ctx, i) => SizedBox(
            width: 170,
            child: CategoryTile(
              name: list[i].name, count: list[i].channelCount,
              onTap: () => ref.read(shellIndexProvider.notifier).state = 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final String title;
  final VoidCallback onMore;
  final Widget child;
  const _Rail({required this.title, required this.onMore, required this.child});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionHeader(title, onMore: onMore), child],
      );
}

Widget _railSkeleton({double height = 230}) => SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => AspectRatio(
          aspectRatio: height > 150 ? AbkAspect.poster : AbkAspect.categoryTile,
          child: const SkeletonBox(radius: AbkRadius.brPoster),
        ),
      ),
    );
