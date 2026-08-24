import 'package:flutter/material.dart';

import '../../core/design/breakpoints.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

/// Caps content at 1680 and centres it on wide displays (Design §02).
class ContentMax extends StatelessWidget {
  final Widget child;
  const ContentMax({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbkBreakpoints.contentMax),
          child: child,
        ),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionHeader(this.title, {super.key, this.onMore});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AbkSpace.s12),
      child: Row(children: [
        Text(title, style: context.type.sectionTitle),
        const Spacer(),
        if (onMore != null)
          IconButton(
            onPressed: onMore,
            icon: Icon(context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: context.c.textSecondary),
          ),
      ]),
    );
  }
}

/// Horizontal snapping rail for cards.
class PosterRail extends StatelessWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;
  const PosterRail({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) {
    final gap = AbkBreakpoints.gridGap(context.wc);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Virtualised poster grid: column count from the width class, fixed poster
/// width, gutters absorb the remainder (Design §02). Lazy — never eager.
class AdaptivePosterGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int, double posterWidth) itemBuilder;
  final EdgeInsets padding;
  final double childAspectRatio; // width/height of the whole cell incl. label
  final ScrollController? controller;
  const AdaptivePosterGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(AbkSpace.s16),
    this.childAspectRatio = 0.52,
    this.controller,
  });
  @override
  Widget build(BuildContext context) {
    final wc = context.wc;
    final cols = AbkBreakpoints.posterColumns(wc);
    final gap = AbkBreakpoints.gridGap(wc);
    return GridView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: gap,
        mainAxisSpacing: AbkBreakpoints.sectionGap(wc) / 2,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (ctx, i) => itemBuilder(ctx, i, 0),
    );
  }
}

/// A scrollable page with the class content margin applied.
class PagePadding extends StatelessWidget {
  final Widget child;
  const PagePadding({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final m = AbkBreakpoints.contentMargin(context.wc);
    return Padding(padding: EdgeInsets.symmetric(horizontal: m), child: child);
  }
}
