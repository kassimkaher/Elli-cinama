import 'package:flutter/material.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';

class _Chip extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Chip(this.text, {required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: AbkRadius.brXs),
      child: Text(text,
          style: context.type.metadata.copyWith(
              color: fg, fontWeight: FontWeight.w700, fontSize: 10, height: 1.3)),
    );
  }
}

/// LIVE — the only content use of accent.secondary (Design §07).
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: context.tr('liveBadge'),
      child: _Chip(context.tr('liveBadge'), bg: context.c.accentSecondary, fg: Colors.white));
}

class RatingBadge extends StatelessWidget {
  final String? rating;
  const RatingBadge(this.rating, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = double.tryParse(rating ?? '');
    if (r == null || r <= 0) return const SizedBox.shrink(); // hidden when null/0
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.scrim, borderRadius: AbkRadius.brXs),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, size: 12, color: c.accentPrimary),
        const SizedBox(width: 3),
        Text(r.toStringAsFixed(1),
            style: context.type.metadata.copyWith(color: c.textPrimary, fontSize: 10)),
      ]),
    );
  }
}

class QualityBadge extends StatelessWidget {
  final String label; // resolved quality, e.g. 1080P
  const QualityBadge(this.label, {super.key});
  @override
  Widget build(BuildContext context) => _Chip(label.toUpperCase(),
      bg: context.c.surfaceStrong, fg: context.c.textSecondary);
}

class LockedBadge extends StatelessWidget {
  const LockedBadge({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: context.tr('locked'),
        child: Icon(Icons.lock_rounded, size: 14, color: context.c.textMuted),
      );
}

class ArchiveBadge extends StatelessWidget {
  const ArchiveBadge({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: context.tr('archive'),
      child: _Chip(context.tr('archive'), bg: context.c.surfaceStrong, fg: context.c.textMuted));
}

/// Metadata row (Design §07): separators only between present values; empty
/// collapses to zero height. Arabic uses product face, not mono.
class MetadataRow extends StatelessWidget {
  final List<String?> values;
  final TextStyle? style;
  const MetadataRow(this.values, {super.key, this.style});
  @override
  Widget build(BuildContext context) {
    final present = values.where((v) => v != null && v.trim().isNotEmpty).cast<String>().toList();
    if (present.isEmpty) return const SizedBox.shrink();
    final st = (style ?? (context.isRtl ? context.type.caption : context.type.metadata));
    return Text(present.join('  ·  '),
        maxLines: 1, overflow: TextOverflow.ellipsis, style: st);
  }
}

/// Optimistic local favourite toggle (Design §07). No progress spinner.
class FavoriteButton extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;
  final double size;
  const FavoriteButton({super.key, required this.active, required this.onToggle, this.size = 22});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: context.tr('favorites'),
      toggled: active,
      child: IconButton(
        iconSize: size,
        visualDensity: VisualDensity.compact,
        onPressed: onToggle,
        icon: AnimatedSwitcher(
          duration: AbkMotion.fast,
          child: Icon(active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(active), color: active ? c.accentPrimary : c.textSecondary),
        ),
      ),
    );
  }
}
