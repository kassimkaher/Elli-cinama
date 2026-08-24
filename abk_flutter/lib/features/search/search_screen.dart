import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../shared/state/states.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/layout.dart';
import '../catalogue/catalogue_providers.dart';
import '../live/presentation/live_browser_screen.dart';
import '../movies/presentation/movie_details_screen.dart';
import 'local_search.dart';
import '../series/presentation/series_details_screen.dart';

final _queryProvider = StateProvider.autoDispose<String>((_) => '');

/// Global LOCAL search across Live / Movies / Series (Design §60). No backend
/// calls per query — filters the already-retrieved catalogues.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      ref.read(_queryProvider.notifier).state = v.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = ref.watch(_queryProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: AbkBreakpoints.contentMargin(context.wc)),
          child: SearchField(
            controller: _controller,
            autofocus: true,
            hint: context.tr('searchEverything'),
            onChanged: _onChanged,
            onClear: () {
              _controller.clear();
              ref.read(_queryProvider.notifier).state = '';
            },
          ),
        ),
      ),
      body: q.isEmpty
          ? EmptyStateBlock(icon: Icons.search_rounded, title: context.tr('searchIdle'))
          : _Results(query: q),
    );
  }
}

class _Results extends ConsumerWidget {
  final String query;
  const _Results({required this.query});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(liveChannelsProvider).valueOrNull ?? const [];
    final movies = ref.watch(moviesProvider).valueOrNull ?? const [];
    final series = ref.watch(seriesListProvider).valueOrNull ?? const [];

    final chHits = LocalSearch.filter(channels, query, (c) => c.name, limit: 40);
    final mHits = LocalSearch.filter(movies, query, (m) => m.name, limit: 40);
    final sHits = LocalSearch.filter(series, query, (s) => s.title, limit: 40);

    if (chHits.isEmpty && mHits.isEmpty && sHits.isEmpty) {
      return EmptyStateBlock(
          icon: Icons.search_off_rounded, title: context.tr('noResults'), body: context.tr('noResultsBody'));
    }

    final m = AbkBreakpoints.contentMargin(context.wc);
    return ContentMax(
      child: ListView(padding: EdgeInsets.symmetric(horizontal: m, vertical: AbkSpace.s8), children: [
        if (chHits.isNotEmpty) ...[
          SectionHeader('${context.tr('live')} · ${chHits.length}'),
          ...chHits.take(12).map((ch) => LiveChannelRow(
                name: ch.name,
                number: '${ch.viewOrder ?? ch.id}',
                logoUrl: ch.icon,
                onTap: () => playChannel(context, ref, ch),
              )),
          const SizedBox(height: AbkSpace.s20),
        ],
        if (mHits.isNotEmpty) ...[
          SectionHeader('${context.tr('movies')} · ${mHits.length}'),
          PosterRail(
            height: 200,
            itemCount: mHits.length,
            itemBuilder: (ctx, i) => PosterCard(
              title: mHits[i].name, imageUrl: mHits[i].icon, compact: true, width: 120,
              onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: mHits[i]))),
            ),
          ),
          const SizedBox(height: AbkSpace.s20),
        ],
        if (sHits.isNotEmpty) ...[
          SectionHeader('${context.tr('series')} · ${sHits.length}'),
          PosterRail(
            height: 200,
            itemCount: sHits.length,
            itemBuilder: (ctx, i) => PosterCard(
              title: sHits[i].title, imageUrl: sHits[i].icon, compact: true, width: 120,
              onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => SeriesDetailsScreen(series: sHits[i]))),
            ),
          ),
        ],
      ]),
    );
  }
}
