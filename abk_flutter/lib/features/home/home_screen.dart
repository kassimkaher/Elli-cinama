import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/images.dart';
import '../../shared/widgets/layout.dart';
import '../catalogue/catalogue_providers.dart';
import '../live/presentation/live_browser_screen.dart';
import '../movies/domain/entities.dart';
import '../movies/presentation/movie_details_screen.dart';
import '../series/presentation/series_details_screen.dart';
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
                ),
              ),
              SizedBox(height: AbkBreakpoints.sectionGap(context.wc)),
            ]),
      orElse: () => const SizedBox.shrink(),
    );
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
