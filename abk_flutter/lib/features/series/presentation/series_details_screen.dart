import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/strings.dart';
import '../../../shared/state/states.dart';
import '../../../shared/widgets/badges.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/focusable.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/images.dart';
import '../../../shared/widgets/layout.dart';
import '../../catalogue/catalogue_providers.dart';
import '../../player/player_screen.dart';
import '../../settings/parental_gate.dart';
import '../domain/entities.dart';

final _seasonProvider = StateProvider.autoDispose<int>((_) => 0);

class SeriesDetailsScreen extends ConsumerWidget {
  final SeriesListItem series;
  const SeriesDetailsScreen({super.key, required this.series});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(seriesInfoProvider(series.id));
    final c = context.c;
    return Scaffold(
      body: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorBlock(onRetry: () => ref.invalidate(seriesInfoProvider(series.id)))),
        data: (d) {
          final seasons = d.seasons;
          final seasonIdx = seasons.isEmpty ? 0 : ref.watch(_seasonProvider).clamp(0, seasons.length - 1);
          final episodes = seasons.isEmpty ? <Episode>[] : seasons[seasonIdx].episodes;
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: c.background,
              leading: BackButton(color: c.textPrimary),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  AbkImage(
                      url: (d.info?.backdrops.isNotEmpty ?? false) ? d.info!.backdrops.first : series.backdrop ?? series.icon,
                      fallback: PosterFallback(series.title)),
                  const Positioned.fill(child: BackdropScrim(heightFactor: 0.9)),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentMax(
                child: PagePadding(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AbkSpace.s20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.info?.title ?? series.title, style: context.type.pageTitle),
                      const SizedBox(height: AbkSpace.s8),
                      MetadataRow([d.info?.genre ?? series.genre, series.releaseDate, series.rating]),
                      const SizedBox(height: AbkSpace.s16),
                      if ((d.info?.plot ?? series.plot ?? '').isNotEmpty)
                        ScrollFocusStop(
                          child: Text(d.info?.plot ?? series.plot!,
                              style: context.type.body.copyWith(color: c.textSecondary)),
                        ),
                      const SizedBox(height: AbkSpace.s20),
                      if (seasons.length > 1)
                        FilterChipRow<int>(
                          options: [for (var i = 0; i < seasons.length; i++) (i, '${context.tr('season')} ${seasons[i].seasonNum}')],
                          selected: seasonIdx,
                          onSelected: (v) => ref.read(_seasonProvider.notifier).state = v,
                        ),
                      const SizedBox(height: AbkSpace.s12),
                      if (episodes.isEmpty)
                        EmptyStateBlock(icon: Icons.playlist_play_rounded, title: context.tr('empty'))
                      else
                        ...episodes.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: AbkSpace.s8),
                              child: EpisodeCard(
                                title: '${e.episodeNum ?? ''}  ${e.episodeName ?? ''}'.trim(),
                                subtitle: d.info?.title ?? series.title,
                                thumbUrl: series.icon,
                                // TV: land visible first-frame focus on the first
                                // episode (matches Movie details autofocusing Play).
                                autofocus: AbkBreakpoints.isTv && e == episodes.first,
                                onTap: () => _playEpisode(context, ref, episodes, episodes.indexOf(e), d),
                              ),
                            )),
                      const SizedBox(height: AbkSpace.s24),
                    ]),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _playEpisode(
      BuildContext context, WidgetRef ref, List<Episode> eps, int index, SeriesInfo d) async {
    final cats = ref.read(seriesCategoriesProvider).valueOrNull;
    final catLocked =
        cats?.any((c) => c.id == series.categoryId && c.isLocked) ?? false;
    final allowed = await ensureUnlocked(context, ref,
        kind: 'series', id: series.id, categoryLocked: catLocked);
    if (!allowed || !context.mounted) return;
    final title = d.info?.title ?? series.title;
    final playableEps = eps.where((e) => (e.streamUrl ?? '').isNotEmpty).toList();
    if (playableEps.isEmpty) {
      showAbkSnackbar(context, context.tr('streamFailed'));
      return;
    }
    final items = playableEps
        .map((e) => PlaybackItem(
              url: e.streamUrl!,
              title: '$title · ${e.episodeName ?? ''}'.trim(),
              subtitle: e.episodeNum != null ? '${context.tr('episode')} ${e.episodeNum}' : null,
              resumeId: '${series.id}_${e.episodeNum}',
              kind: 'episode',
              image: series.icon,
            ))
        .toList();
    var i = playableEps.indexOf(eps[index]);
    if (i < 0) i = 0;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(items: items, index: i)));
  }
}
