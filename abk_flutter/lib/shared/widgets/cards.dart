import 'package:flutter/material.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import 'badges.dart';
import 'focusable.dart';
import 'images.dart';

/// PosterCard (2:3) — movies & series. Artwork scales on hover/focus; the label
/// never scales so rows never reflow (Design §07).
class PosterCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final List<String?> meta;
  final String? rating;
  final bool locked;
  final bool disabled;
  final bool compact; // search/favourites: drops metadata
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onSecondary;

  const PosterCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.meta = const [],
    this.rating,
    this.locked = false,
    this.disabled = false,
    this.compact = false,
    required this.width,
    this.onTap,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: width,
      child: AbkFocusable(
        onTap: onTap,
        onSecondary: onSecondary,
        radius: AbkRadius.brPoster,
        disabled: disabled,
        semanticLabel: title,
        builder: (ctx, states) {
          final active = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: AspectRatio(
              aspectRatio: AbkAspect.poster,
              child: Opacity(
                opacity: disabled ? 0.45 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AbkRadius.brPoster,
                    border: c.cardBorder ? Border.all(color: c.borderSubtle) : null,
                  ),
                  child: Stack(fit: StackFit.expand, children: [
                    AnimatedScale(
                      // On TV the whole card already grows (outer 1.06 ring), so
                      // the inner artwork scale is dropped to avoid ~1.10 stacking
                      // that clips neighbours.
                      scale: active && !reduce && !AbkBreakpoints.isTv ? 1.04 : 1.0,
                      duration: reduce ? Duration.zero : AbkMotion.hover,
                      child: AbkImage(
                          url: imageUrl, radius: AbkRadius.brPoster, fallback: PosterFallback(title)),
                    ),
                    if (rating != null)
                      Positioned(top: 6, left: 6, child: RatingBadge(rating)),
                    if (locked)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: c.scrim, borderRadius: AbkRadius.brPoster),
                          child: const Center(child: LockedBadge()),
                        ),
                      ),
                    if (active && !locked)
                      const Positioned.fill(child: BackdropScrim(heightFactor: 0.4)),
                    if (active && !locked)
                      Positioned(
                        bottom: 8, left: 8, right: 8,
                        child: Row(children: [
                          Container(
                            padding: EdgeInsets.all(AbkBreakpoints.isTv ? 8 : 6),
                            decoration: BoxDecoration(color: c.accentPrimary, shape: BoxShape.circle),
                            child: Icon(Icons.play_arrow_rounded,
                                size: AbkBreakpoints.isTv ? 26 : 18, color: c.background),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: AbkSpace.s8),
            Text(title,
                // TV: pin to one line so a focused card never reflows its row.
                maxLines: AbkBreakpoints.isTv ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.cardTitle.copyWith(
                    fontWeight: AbkBreakpoints.isTv && active ? FontWeight.w700 : null,
                    color: AbkBreakpoints.isTv && active ? c.textPrimary : null)),
            if (!compact) MetadataRow(meta),
          ]);
        },
      ),
    );
  }
}

class ContinueWatchingCard extends StatelessWidget {
  final String title, subtitle;
  final String? imageUrl;
  final double progress; // 0..1
  final VoidCallback? onTap;
  final double width;
  const ContinueWatchingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.progress,
    required this.width,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: width,
      child: AbkFocusable(
        onTap: onTap,
        radius: AbkRadius.brMd,
        semanticLabel: title,
        builder: (ctx, states) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: AspectRatio(
            aspectRatio: AbkAspect.continueWatching,
            child: Stack(fit: StackFit.expand, children: [
              AbkImage(url: imageUrl, radius: AbkRadius.brMd, fallback: PosterFallback(title)),
              const Positioned.fill(child: BackdropScrim(heightFactor: 0.5)),
              Positioned(
                left: 8, right: 8, bottom: 8,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: c.accentPrimary, shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow_rounded, size: 16, color: c.background),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 3,
                        backgroundColor: c.playerOverlay,
                        color: c.accentPrimary),
                  ),
                ]),
              ),
            ]),
          )),
          const SizedBox(height: AbkSpace.s8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.cardTitle),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.caption),
        ]),
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  final String name;
  final int? count;
  final IconData icon;
  final VoidCallback? onTap;
  const CategoryTile({super.key, required this.name, this.count, this.icon = Icons.category_rounded, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AbkFocusable(
      onTap: onTap,
      radius: AbkRadius.brMd,
      semanticLabel: name,
      builder: (ctx, states) => AspectRatio(
        aspectRatio: AbkAspect.categoryTile,
        child: Container(
          padding: const EdgeInsets.all(AbkSpace.s16),
          decoration: BoxDecoration(
            color: states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                ? c.cardFocused : c.card,
            borderRadius: AbkRadius.brMd,
            border: c.cardBorder ? Border.all(color: c.borderSubtle) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: c.accentPrimary, size: 22),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.cardTitle),
                if (count != null)
                  Text('$count', style: context.type.metadata),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryRailItem extends StatelessWidget {
  final String name;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;
  const CategoryRailItem({super.key, required this.name, this.count, this.selected = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AbkFocusable(
      onTap: onTap,
      radius: AbkRadius.brSm,
      selected: selected,
      semanticLabel: name,
      builder: (ctx, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? c.surfaceStrong
              : (states.contains(WidgetState.hovered) ? c.surfaceElevated : Colors.transparent),
          borderRadius: AbkRadius.brSm,
          border: Border(
              right: BorderSide(color: selected ? c.accentPrimary : Colors.transparent, width: 2)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: context.type.body.copyWith(
                    color: selected ? c.textPrimary : c.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ),
          if (count != null) Text('$count', style: context.type.metadata),
        ]),
      ),
    );
  }
}

class EpisodeCard extends StatelessWidget {
  final String title, subtitle;
  final String? thumbUrl;
  final double? progress;
  final VoidCallback? onTap;
  const EpisodeCard({super.key, required this.title, required this.subtitle, this.thumbUrl, this.progress, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AbkFocusable(
      onTap: onTap,
      radius: AbkRadius.brMd,
      semanticLabel: title,
      builder: (ctx, states) => Container(
        padding: const EdgeInsets.all(AbkSpace.s8),
        decoration: BoxDecoration(
          color: states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)
              ? c.cardFocused : c.card,
          borderRadius: AbkRadius.brMd,
          border: c.cardBorder ? Border.all(color: c.borderSubtle) : null,
        ),
        child: Row(children: [
          SizedBox(
            width: 128,
            child: AspectRatio(
              aspectRatio: AbkAspect.episodeThumb,
              child: Stack(fit: StackFit.expand, children: [
                AbkImage(url: thumbUrl, radius: AbkRadius.brSm, fallback: PosterFallback(title)),
                if (progress != null)
                  Positioned(
                    left: 4, right: 4, bottom: 4,
                    child: LinearProgressIndicator(
                        value: progress, minHeight: 3, backgroundColor: c.playerOverlay, color: c.accentPrimary),
                  ),
                Center(child: Icon(Icons.play_circle_fill_rounded, color: c.textPrimary.withValues(alpha: 0.9), size: 28)),
              ]),
            ),
          ),
          const SizedBox(width: AbkSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.cardTitle),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.bodySecondary),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// LiveChannelRow — compact list (phone, desktop list). Channel number comes
/// from view_order, never the stream id (Design §07). Locked rows show identity
/// but never artwork.
class LiveChannelRow extends StatelessWidget {
  final String name;
  final String number;
  final String? subtitle; // category, or "Now: …" when EPG exists
  final String? logoUrl;
  final bool live, locked, archive, favorite, selected;
  // Large-screen preview states — independent layers so they coexist (a row can
  // be focused + selected + playing). `selected` = loaded in the preview;
  // `playing` = actually decoding; `loading` = switching source; `channelError`
  // = failed to play.
  final bool playing, loading, channelError;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onSecondary;
  const LiveChannelRow({
    super.key,
    required this.name,
    required this.number,
    this.subtitle,
    this.logoUrl,
    this.live = false,
    this.locked = false,
    this.archive = false,
    this.favorite = false,
    this.selected = false,
    this.playing = false,
    this.loading = false,
    this.channelError = false,
    this.onTap,
    this.onToggleFavorite,
    this.onSecondary,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Leading state bar colour (priority: error > playing/loading/selected).
    final barColor = channelError
        ? c.error
        : (playing || loading)
            ? c.accentPrimary
            : (selected ? c.accentPrimary.withValues(alpha: 0.6) : Colors.transparent);
    return AbkFocusable(
      onTap: onTap,
      onSecondary: onSecondary,
      radius: AbkRadius.brSm,
      selected: selected,
      semanticLabel: name,
      builder: (ctx, states) => Container(
        height: 64,
        padding: const EdgeInsets.only(right: 10, left: 10),
        decoration: BoxDecoration(
          color: channelError
              ? c.error.withValues(alpha: 0.08)
              : playing
                  ? c.accentPrimary.withValues(alpha: 0.10)
                  : selected
                      ? c.surfaceStrong
                      : (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                          ? c.surfaceElevated : Colors.transparent),
          borderRadius: AbkRadius.brSm,
          border: c.cardBorder ? Border.all(color: c.borderSubtle) : null,
        ),
        child: Row(children: [
          // Leading state bar (directional start edge).
          Container(
            width: 3, height: 40,
            decoration: BoxDecoration(color: barColor, borderRadius: AbkRadius.brPill),
          ),
          const SizedBox(width: 8),
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: c.surfaceStrong, borderRadius: AbkRadius.brSm),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(6),
              child: locked
                  ? Icon(Icons.lock_rounded, size: 18, color: c.textMuted)
                  : AbkImage(url: logoUrl, fit: BoxFit.contain, fallback: LogoFallback(name)),
            ),
            // Leading indicator overlay: loading spinner / playing equalizer /
            // error glyph — makes the actively-decoding channel unmistakable.
            if (loading)
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: c.scrim, borderRadius: AbkRadius.brSm),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.accentPrimary),
                ),
              )
            else if (channelError)
              Icon(Icons.error_outline_rounded, size: 22, color: c.error)
            else if (playing)
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: c.accentPrimary.withValues(alpha: 0.28), borderRadius: AbkRadius.brSm),
                child: Icon(Icons.graphic_eq_rounded, size: 22, color: c.accentPrimary),
              ),
          ]),
          const SizedBox(width: AbkSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.cardTitle.copyWith(
                              color: playing ? c.accentPrimary : null))),
                  if (playing) ...[const SizedBox(width: 8), const LiveBadge()]
                  else if (live) ...[const SizedBox(width: 8), const LiveBadge()],
                  if (archive) ...[const SizedBox(width: 6), const ArchiveBadge()],
                ]),
                if (loading)
                  Text('$number  ·  ${context.tr('loading')}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: context.type.metadata.copyWith(color: c.accentPrimary))
                else if (channelError)
                  Text('$number  ·  ${context.tr('unavailable')}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: context.type.metadata.copyWith(color: c.error))
                else if (subtitle != null)
                  Text('$number  ·  ${subtitle!}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.metadata)
                else
                  Text(number, style: context.type.metadata),
              ],
            ),
          ),
          if (onToggleFavorite != null)
            FavoriteButton(active: favorite, onToggle: onToggleFavorite!, size: 20),
        ]),
      ),
    );
  }
}

/// HeroBanner (16:9 backdrop). Omitted by the caller when no backdrop qualifies.
class HeroBanner extends StatelessWidget {
  final String title;
  final List<String?> meta;
  final String? backdropUrl;
  final VoidCallback? onPlay;
  final VoidCallback? onDetails;
  final String playLabel, detailsLabel;
  const HeroBanner({
    super.key,
    required this.title,
    required this.meta,
    required this.backdropUrl,
    this.onPlay,
    this.onDetails,
    required this.playLabel,
    required this.detailsLabel,
  });
  @override
  Widget build(BuildContext context) {
    final content = Stack(fit: StackFit.expand, children: [
          AbkImage(url: backdropUrl, fit: BoxFit.cover, fallback: PosterFallback(title)),
          const Positioned.fill(child: BackdropScrim(heightFactor: 0.85)),
          Positioned(
            left: AbkSpace.s24, right: AbkSpace.s24, bottom: AbkSpace.s24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: context.type.hero.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                MetadataRow(meta, style: context.type.metadata.copyWith(color: Colors.white70)),
                const SizedBox(height: AbkSpace.s16),
                Row(children: [
                  if (onPlay != null)
                    _HeroBtn(icon: Icons.play_arrow_rounded, label: playLabel, filled: true, onTap: onPlay!),
                  if (onDetails != null) ...[
                    const SizedBox(width: 12),
                    _HeroBtn(icon: Icons.info_outline_rounded, label: detailsLabel, filled: false, onTap: onDetails!),
                  ],
                ]),
              ],
            ),
          ),
        ]);
    // On TV, cap the hero to ~half the viewport height (instead of a full-width
    // 16:9 that eats the whole screen) so the first content rail peeks below and
    // invites D-pad-down; the backdrop covers the shorter box.
    final sized = AbkBreakpoints.isTv
        ? SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.52).clamp(240.0, 480.0),
            child: content)
        : AspectRatio(aspectRatio: AbkAspect.backdrop, child: content);
    return ClipRRect(borderRadius: AbkRadius.brLg, child: sized);
  }
}

class _HeroBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _HeroBtn({required this.icon, required this.label, required this.filled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AbkFocusable(
      onTap: onTap,
      radius: AbkRadius.brSm,
      semanticLabel: label,
      builder: (ctx, s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: filled ? c.accentPrimary : Colors.white.withValues(alpha: 0.16),
          borderRadius: AbkRadius.brSm,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: filled ? c.background : Colors.white),
          const SizedBox(width: 8),
          Text(label, style: context.type.button.copyWith(color: filled ? c.background : Colors.white)),
        ]),
      ),
    );
  }
}
