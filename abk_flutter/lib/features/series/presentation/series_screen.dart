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
import 'series_details_screen.dart';

enum SeriesSort { defaultOrder, name, rating }

final _seriesCatProvider = StateProvider<String?>((_) => null);
final _seriesSortProvider = StateProvider<SeriesSort>((_) => SeriesSort.defaultOrder);

class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesListProvider);
    final cats = ref.watch(seriesCategoriesProvider);
    final selectedCat = ref.watch(_seriesCatProvider);
    final sort = ref.watch(_seriesSortProvider);

    return series.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorBlock(onRetry: () => ref.invalidate(seriesListProvider)),
      data: (all) {
        var list = selectedCat == null ? all : all.where((s) => s.categoryId == selectedCat).toList();
        list = _sorted(list, sort);
        final catOptions = <(String?, String)>[(null, context.tr('allChannels'))];
        cats.whenData((cs) {
          for (final ca in cs) { catOptions.add((ca.id, ca.name)); }
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
                  onSelected: (v) => ref.read(_seriesCatProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 8),
              SortSelector<SeriesSort>(
                title: context.tr('sortBy'),
                selected: sort,
                onSelected: (v) => ref.read(_seriesSortProvider.notifier).state = v,
                options: [
                  (SeriesSort.defaultOrder, context.tr('sortDefault')),
                  (SeriesSort.name, context.tr('sortName')),
                  (SeriesSort.rating, context.tr('sortRating')),
                ],
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyStateBlock(icon: Icons.grid_view_rounded, title: context.tr('empty'))
                : ContentMax(
                    child: AdaptivePosterGrid(
                      itemCount: list.length,
                      itemBuilder: (ctx, i, _) {
                        final s = list[i];
                        return PosterCard(
                          title: s.title,
                          imageUrl: s.icon,
                          rating: s.rating,
                          meta: [s.genre],
                          width: double.infinity,
                          onTap: () => Navigator.of(ctx).push(
                              MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: s))),
                        );
                      },
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  List<SeriesListItem> _sorted(List<SeriesListItem> list, SeriesSort s) {
    final copy = [...list];
    switch (s) {
      case SeriesSort.defaultOrder:
        break;
      case SeriesSort.name:
        copy.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SeriesSort.rating:
        copy.sort((a, b) => (double.tryParse(b.rating ?? '') ?? 0).compareTo(double.tryParse(a.rating ?? '') ?? 0));
    }
    return copy;
  }
}
