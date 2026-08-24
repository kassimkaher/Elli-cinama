import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/breakpoints.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/i18n/strings.dart';
import '../../../shared/state/states.dart';
import '../../../shared/widgets/badges.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/images.dart';
import '../../../shared/widgets/layout.dart';
import '../../catalogue/catalogue_providers.dart';
import '../../favorites/playback_history_repository.dart';
import '../../player/player_screen.dart';
import '../domain/entities.dart';

class MovieDetailsScreen extends ConsumerWidget {
  final MovieListItem movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(movieInfoProvider(movie.id));
    return Scaffold(
      body: info.when(
        loading: () => const _DetailsSkeleton(),
        error: (e, _) => Center(
            child: ErrorBlock(onRetry: () => ref.invalidate(movieInfoProvider(movie.id)))),
        data: (d) => _DetailsBody(movie: movie, info: d),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  final MovieListItem movie;
  final MovieInfo info;
  const _DetailsBody({required this.movie, required this.info});

  void _play(BuildContext context, WidgetRef ref) {
    final url = ref.read(selectMovieQualityProvider).call(info);
    if (url == null || url.isEmpty) {
      showAbkSnackbar(context, context.tr('streamFailed'));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: url,
        title: info.title,
        subtitle: MetadataText.of(info),
        history: PlaybackEntry(
          id: movie.id, kind: 'movie', title: info.title,
          subtitle: MetadataText.of(info), image: movie.icon,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final wc = context.wc;
    final twoCol = AbkBreakpoints.isDesktopClass(wc) || wc == WidthClass.expanded;
    final meta = [info.year, info.genre, info.duration, info.rating, info.mpaa];

    final poster = ClipRRect(
      borderRadius: AbkRadius.brPoster,
      child: AspectRatio(
        aspectRatio: AbkAspect.poster,
        child: AbkImage(url: movie.icon ?? info.icon, fallback: PosterFallback(info.title)),
      ),
    );

    final actions = Wrap(spacing: 12, runSpacing: 12, children: [
      AbkButton(context.tr('play'), icon: Icons.play_arrow_rounded, autofocus: true, onPressed: () => _play(context, ref)),
      _FavButton(id: movie.id, kind: 'movie'),
      if ((info.trailer ?? '').isNotEmpty)
        AbkButton(context.tr('watchTrailer'), kind: AbkButtonKind.ghost, icon: Icons.ondemand_video_rounded,
            onPressed: () => showAbkSnackbar(context, context.tr('watchTrailer'))),
    ]);

    final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(info.title, style: context.type.pageTitle),
      const SizedBox(height: AbkSpace.s8),
      MetadataRow(meta),
      const SizedBox(height: AbkSpace.s20),
      actions,
      const SizedBox(height: AbkSpace.s24),
      if ((info.plot ?? '').isNotEmpty)
        Text(info.plot!, style: context.type.body.copyWith(color: c.textSecondary)),
      if ((info.cast ?? '').isNotEmpty) ...[
        const SizedBox(height: AbkSpace.s16),
        _Field(label: 'Cast', value: info.cast!),
      ],
    ]);

    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: twoCol ? 260 : 220,
        pinned: true,
        backgroundColor: c.background,
        leading: BackButton(color: c.textPrimary),
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(fit: StackFit.expand, children: [
            AbkImage(url: movie.backdrop ?? movie.icon, fallback: PosterFallback(info.title)),
            const Positioned.fill(child: BackdropScrim(heightFactor: 0.9)),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: ContentMax(
          child: PagePadding(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AbkSpace.s24),
              child: twoCol
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 220, child: poster),
                      const SizedBox(width: AbkSpace.s32),
                      Expanded(child: details),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Center(child: SizedBox(width: 160, child: poster)),
                      const SizedBox(height: AbkSpace.s24),
                      details,
                    ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class MetadataText {
  static String of(MovieInfo i) => [i.year, i.genre].where((e) => (e ?? '').isNotEmpty).join(' · ');
}

class _Field extends StatelessWidget {
  final String label, value;
  const _Field({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.type.caption),
        const SizedBox(height: 2),
        Text(value, style: context.type.body),
      ]);
}

class _FavButton extends ConsumerWidget {
  final String id, kind;
  const _FavButton({required this.id, required this.kind});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final repo = ref.read(favoritesRepositoryProvider);
    return FutureBuilder<bool>(
      future: repo.isFavorite(kind, id),
      builder: (ctx, snap) {
        final active = snap.data ?? false;
        return AbkButton(
          context.tr('favorites'),
          kind: active ? AbkButtonKind.primary : AbkButtonKind.secondary,
          icon: active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          onPressed: () async {
            await repo.toggle(kind, id);
            ref.read(localRevisionProvider.notifier).state++;
          },
        );
      },
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
