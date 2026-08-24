import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/strings.dart';
import '../../../shared/state/states.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/layout.dart';
import '../../catalogue/catalogue_providers.dart';
import '../domain/entities.dart';
import 'movie_details_screen.dart';

enum MovieSort { defaultOrder, name, year, rating }

final _movieCatProvider = StateProvider<String?>((_) => null); // null = all
final _movieSortProvider = StateProvider<MovieSort>((_) => MovieSort.defaultOrder);

class MoviesScreen extends ConsumerWidget {
  const MoviesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider);
    final cats = ref.watch(movieCategoriesProvider);
    final selectedCat = ref.watch(_movieCatProvider);
    final sort = ref.watch(_movieSortProvider);

    return movies.when(
      loading: () => const _GridSkeleton(),
      error: (e, _) => ErrorBlock(onRetry: () => ref.invalidate(moviesProvider)),
      data: (all) {
        var list = selectedCat == null ? all : all.where((m) => m.categoryId == selectedCat).toList();
        list = _sorted(list, sort);
        final catOptions = <(String?, String)>[(null, context.tr('allChannels'))];
        cats.whenData((cs) {
          for (final ca in cs) {
            catOptions.add((ca.id, ca.name));
          }
        });
        return Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                AbkBreakpoints.contentMargin(context.wc), AbkSpace.s8, AbkBreakpoints.contentMargin(context.wc), AbkSpace.s8),
            child: Row(children: [
              Expanded(
                child: FilterChipRow<String?>(
                  options: catOptions,
                  selected: selectedCat,
                  onSelected: (v) => ref.read(_movieCatProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 8),
              SortSelector<MovieSort>(
                title: context.tr('sortBy'),
                selected: sort,
                onSelected: (v) => ref.read(_movieSortProvider.notifier).state = v,
                options: [
                  (MovieSort.defaultOrder, context.tr('sortDefault')),
                  (MovieSort.name, context.tr('sortName')),
                  (MovieSort.year, context.tr('sortYear')),
                  (MovieSort.rating, context.tr('sortRating')),
                ],
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyStateBlock(icon: Icons.movie_outlined, title: context.tr('empty'))
                : ContentMax(child: _MovieGrid(list: list)),
          ),
        ]);
      },
    );
  }

  List<MovieListItem> _sorted(List<MovieListItem> list, MovieSort s) {
    // Only fields the contract actually provides — no "newest"/"added".
    final copy = [...list];
    switch (s) {
      case MovieSort.defaultOrder:
        break;
      case MovieSort.name:
        copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case MovieSort.year:
        copy.sort((a, b) => (int.tryParse(b.year ?? '') ?? 0).compareTo(int.tryParse(a.year ?? '') ?? 0));
      case MovieSort.rating:
        copy.sort((a, b) => (double.tryParse(b.rating ?? '') ?? 0).compareTo(double.tryParse(a.rating ?? '') ?? 0));
    }
    return copy;
  }
}

class _MovieGrid extends StatelessWidget {
  final List<MovieListItem> list;
  const _MovieGrid({required this.list});
  @override
  Widget build(BuildContext context) {
    return AdaptivePosterGrid(
      itemCount: list.length,
      itemBuilder: (ctx, i, _) {
        final m = list[i];
        return PosterCard(
          title: m.name,
          imageUrl: m.icon,
          rating: m.rating,
          meta: [m.year, m.genre],
          width: double.infinity,
          onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: m))),
        );
      },
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return AdaptivePosterGrid(
      itemCount: 18,
      itemBuilder: (ctx, i, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Expanded(child: SkeletonBox(radius: AbkRadius.brPoster)),
        SizedBox(height: 8),
        SkeletonBox(height: 12, width: 90),
      ]),
    );
  }
}
