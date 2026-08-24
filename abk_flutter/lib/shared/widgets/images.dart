import 'package:flutter/material.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

/// Network image with skeleton → fade-in → designed fallback (Design §07 image
/// system). Never leaves a blank gap; artwork is never re-toned for the theme.
class AbkImage extends StatelessWidget {
  final String? url;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius radius;
  final Widget fallback;

  const AbkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (url == null || url!.isEmpty) {
      return ClipRRect(borderRadius: radius, child: SizedBox(width: width, height: height, child: fallback));
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: width != null && width!.isFinite ? (width! * 2).round() : null,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(width: width, height: height, color: c.skeletonBase);
        },
        frameBuilder: (ctx, child, frame, wasSync) {
          if (wasSync || frame != null) return child;
          return Container(width: width, height: height, color: c.skeletonBase);
        },
        errorBuilder: (ctx, err, st) => SizedBox(width: width, height: height, child: fallback),
      ),
    );
  }
}

/// Poster fallback: a stable placeholder tint (hash(title)%3) with the title.
class PosterFallback extends StatelessWidget {
  final String title;
  const PosterFallback(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.placeholderFor(title),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AbkSpace.s12),
      child: Text(
        title,
        maxLines: 3,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: context.type.cardTitle.copyWith(color: c.textSecondary),
      ),
    );
  }
}

/// Channel/brand logo fallback: initials on surfaceStrong.
class LogoFallback extends StatelessWidget {
  final String name;
  const LogoFallback(this.name, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final letters = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.characters.first).join();
    return Container(
      color: c.surfaceStrong,
      alignment: Alignment.center,
      child: Text(letters.toUpperCase(),
          style: context.type.cardTitle.copyWith(color: c.textMuted, fontWeight: FontWeight.w700)),
    );
  }
}

/// Bottom-up scrim over artwork so text stays legible.
class BackdropScrim extends StatelessWidget {
  final double heightFactor;
  const BackdropScrim({super.key, this.heightFactor = 0.7});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [0, heightFactor, 1],
            colors: [c.scrim, c.scrim.withValues(alpha: c.scrim.a * 0.4), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
