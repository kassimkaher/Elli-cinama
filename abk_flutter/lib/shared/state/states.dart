import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../widgets/buttons.dart';

/// Shimmering skeleton (Design §06 motion.shimmer). Static tint under reduced
/// motion.
class SkeletonBox extends StatefulWidget {
  final double? width, height;
  final BorderRadius radius;
  const SkeletonBox({super.key, this.width, this.height, this.radius = AbkRadius.brSm});
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: AbkMotion.shimmer)..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      return Container(
          width: widget.width, height: widget.height,
          decoration: BoxDecoration(color: c.skeletonBase, borderRadius: widget.radius));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final x = _ctrl.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(-1 - x, 0),
              end: Alignment(1 - x, 0),
              colors: [c.skeletonBase, c.skeletonHi, c.skeletonBase],
            ),
          ),
        );
      },
    );
  }
}

class EmptyStateBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyStateBlock({super.key, required this.icon, required this.title, this.body, this.action});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AbkSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: c.textMuted),
          const SizedBox(height: AbkSpace.s16),
          Text(title, textAlign: TextAlign.center, style: context.type.sectionTitle),
          if (body != null) ...[
            const SizedBox(height: AbkSpace.s8),
            Text(body!, textAlign: TextAlign.center, style: context.type.bodySecondary),
          ],
          if (action != null) ...[const SizedBox(height: AbkSpace.s20), action!],
        ]),
      ),
    );
  }
}

/// Sanitized error block — never surfaces raw network/XOR/backend detail.
class ErrorBlock extends StatelessWidget {
  final String? title;
  final String? body;
  final VoidCallback? onRetry;
  final bool compact;
  const ErrorBlock({super.key, this.title, this.body, this.onRetry, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final t = title ?? context.tr('somethingWrong');
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(AbkSpace.s16),
        decoration: BoxDecoration(
            color: context.c.surfaceElevated,
            borderRadius: AbkRadius.brMd,
            border: Border.all(color: context.c.borderSubtle)),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 20, color: context.c.textMuted),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: context.type.cardTitle),
            if (body != null) Text(body!, style: context.type.caption),
          ])),
          if (onRetry != null)
            AbkButton(context.tr('retry'), kind: AbkButtonKind.ghost, onPressed: onRetry),
        ]),
      );
    }
    return EmptyStateBlock(
      icon: Icons.error_outline_rounded,
      title: t,
      body: body,
      action: onRetry == null ? null : AbkButton(context.tr('retry'), icon: Icons.refresh_rounded, onPressed: onRetry),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => _Banner(
      icon: Icons.wifi_off_rounded, text: context.tr('offline'), color: context.c.warning);
}

class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key});
  @override
  Widget build(BuildContext context) => _Banner(
      icon: Icons.history_rounded, text: context.tr('staleData'), color: context.c.info);
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Banner({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s16, vertical: 10),
      color: color.withValues(alpha: 0.14),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(text, style: context.type.caption.copyWith(color: context.c.textPrimary)),
      ]),
    );
  }
}

/// Maps an [AsyncValue] list to loading skeleton / sanitized error / empty /
/// data (Design §70 CatalogueLoading/Ready/Empty/RefreshFailed).
class SectionAsync<T> extends StatelessWidget {
  final AsyncValue<List<T>> value;
  final Widget Function(List<T> data) data;
  final Widget skeleton;
  final VoidCallback? onRetry;
  final Widget Function()? emptyBuilder;
  const SectionAsync({
    super.key,
    required this.value,
    required this.data,
    required this.skeleton,
    this.onRetry,
    this.emptyBuilder,
  });
  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => skeleton,
      error: (e, _) => ErrorBlock(compact: true, onRetry: onRetry, body: context.tr('sectionFailedBody')),
      data: (list) {
        if (list.isEmpty) {
          return emptyBuilder?.call() ??
              EmptyStateBlock(icon: Icons.inbox_rounded, title: context.tr('empty'));
        }
        return data(list);
      },
    );
  }
}

void showAbkSnackbar(BuildContext context, String message) {
  final c = context.c;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: c.surfaceStrong,
    content: Text(message, style: context.type.body),
    shape: const RoundedRectangleBorder(borderRadius: AbkRadius.brMd),
  ));
}

Future<T?> showAbkSheet<T>(BuildContext context, WidgetBuilder builder) {
  final c = context.c;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.surfaceElevated,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AbkRadius.sheet)),
    builder: builder,
  );
}

Future<T?> showAbkDialog<T>(BuildContext context, {required String title, required Widget content, List<Widget>? actions}) {
  final c = context.c;
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: c.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(AbkRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AbkSpace.s24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.type.sectionTitle),
            const SizedBox(height: AbkSpace.s16),
            content,
            if (actions != null) ...[
              const SizedBox(height: AbkSpace.s24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
              ]),
            ],
          ]),
        ),
      ),
    ),
  );
}
