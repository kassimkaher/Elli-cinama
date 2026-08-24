import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/di/providers.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/layout.dart';
import '../catalogue/catalogue_providers.dart';
import '../live/presentation/live_browser_screen.dart';
import '../movies/presentation/movie_details_screen.dart';
import '../series/presentation/series_details_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final favRepo = ref.read(favoritesRepositoryProvider);
    final channels = ref.watch(favoriteChannelsProvider).valueOrNull ?? const [];
    final movies = ref.watch(moviesProvider).valueOrNull ?? const [];
    final series = ref.watch(seriesListProvider).valueOrNull ?? const [];

    return FutureBuilder(
      future: Future.wait([favRepo.getFavorites('movie'), favRepo.getFavorites('series')]),
      builder: (ctx, snap) {
        final movieIds = snap.hasData ? snap.data![0] : <String>{};
        final seriesIds = snap.hasData ? snap.data![1] : <String>{};
        final favMovies = movies.where((m) => movieIds.contains(m.id)).toList();
        final favSeries = series.where((s) => seriesIds.contains(s.id)).toList();

        if (channels.isEmpty && favMovies.isEmpty && favSeries.isEmpty) {
          return EmptyStateBlock(
            icon: Icons.favorite_border_rounded,
            title: context.tr('favoritesEmpty'),
            body: context.tr('favoritesEmptyBody'),
          );
        }
        final m = AbkBreakpoints.contentMargin(context.wc);
        return ContentMax(
          child: ListView(padding: EdgeInsets.symmetric(horizontal: m, vertical: AbkSpace.s16), children: [
            if (channels.isNotEmpty) ...[
              SectionHeader(context.tr('live')),
              ...channels.map((ch) => LiveChannelRow(
                    name: ch.name, number: '${ch.viewOrder ?? ch.id}', logoUrl: ch.icon, favorite: true,
                    onTap: () => playChannel(context, ref, ch),
                    onToggleFavorite: () async {
                      await favRepo.toggle('live', '${ch.id}');
                      ref.read(localRevisionProvider.notifier).state++;
                    },
                  )),
              const SizedBox(height: AbkSpace.s24),
            ],
            if (favMovies.isNotEmpty) ...[
              SectionHeader(context.tr('movies')),
              PosterRail(
                height: 230,
                itemCount: favMovies.length,
                itemBuilder: (c, i) => PosterCard(
                  title: favMovies[i].name, imageUrl: favMovies[i].icon, rating: favMovies[i].rating,
                  meta: [favMovies[i].year], width: AbkBreakpoints.posterWidth(c.wc),
                  onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: favMovies[i]))),
                ),
              ),
              const SizedBox(height: AbkSpace.s24),
            ],
            if (favSeries.isNotEmpty) ...[
              SectionHeader(context.tr('series')),
              PosterRail(
                height: 230,
                itemCount: favSeries.length,
                itemBuilder: (c, i) => PosterCard(
                  title: favSeries[i].title, imageUrl: favSeries[i].icon, rating: favSeries[i].rating,
                  meta: [favSeries[i].genre], width: AbkBreakpoints.posterWidth(c.wc),
                  onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: favSeries[i]))),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}
