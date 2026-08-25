import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

/// The one interaction contract for cards/controls (Design §06/§07):
/// hover (desktop), focus (keyboard/TV), pressed, selected — with a focus ring,
/// press scale, and optional artwork scale. Reduced-motion aware. Secondary
/// activation (long-press / right-click / menu key) opens quick actions.
class AbkFocusable extends StatefulWidget {
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;
  final VoidCallback? onTap;
  final VoidCallback? onSecondary;
  final BorderRadius radius;
  final bool selected;
  final bool disabled;
  final double focusScale; // artwork/card focus scale (1.0 = none)
  final bool autofocus;
  final String? semanticLabel;

  const AbkFocusable({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondary,
    this.radius = AbkRadius.brMd,
    this.selected = false,
    this.disabled = false,
    this.focusScale = 1.0,
    this.autofocus = false,
    this.semanticLabel,
  });

  @override
  State<AbkFocusable> createState() => _AbkFocusableState();
}

class _AbkFocusableState extends State<AbkFocusable> {
  bool _hover = false, _focus = false, _pressed = false;

  Set<WidgetState> get _states => {
        if (_hover) WidgetState.hovered,
        if (_focus) WidgetState.focused,
        if (_pressed) WidgetState.pressed,
        if (widget.selected) WidgetState.selected,
        if (widget.disabled) WidgetState.disabled,
      };

  void _activate() {
    if (!widget.disabled) widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scale = (_pressed && !widget.disabled)
        ? 0.98
        : (_focus && widget.focusScale != 1.0 && !reduce ? widget.focusScale : 1.0);

    Widget child = widget.builder(context, _states);

    // Focus ring (keyboard/TV): 2dp ring at 3dp offset.
    if (_focus) {
      child = Container(
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          boxShadow: reduce ? null : AbkElevation.focus,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: widget.radius,
          border: Border.all(color: c.focusRing, width: 2),
        ),
        child: child,
      );
    }

    child = AnimatedScale(
      scale: scale,
      duration: reduce ? Duration.zero : AbkMotion.focusMove,
      curve: AbkMotion.emphasized,
      child: child,
    );

    return FocusableActionDetector(
      enabled: !widget.disabled,
      autofocus: widget.autofocus,
      mouseCursor: widget.disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        // Android TV / Google TV D-pad centre.
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _activate();
          return null;
        }),
      },
      child: Semantics(
        label: widget.semanticLabel,
        selected: widget.selected,
        button: widget.onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onLongPress: widget.onSecondary,
          onSecondaryTap: widget.onSecondary,
          child: child,
        ),
      ),
    );
  }
}
