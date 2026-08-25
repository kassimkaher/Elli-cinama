import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/breakpoints.dart';
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
  final FocusNode? focusNode; // supply to drive/observe focus externally
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
    this.focusNode,
    this.semanticLabel,
  });

  @override
  State<AbkFocusable> createState() => _AbkFocusableState();
}

/// A focusable, non-activating "scroll stop" for TV. Lets D-pad focus land on an
/// otherwise-unfocusable content block (e.g. a long description / cast list) so
/// the page scrolls it into view and the viewer can read below-the-fold content
/// with the remote. A subtle tint+border keeps the focus visible WITHOUT scaling
/// the text. Off-TV it returns the child unchanged (mouse/touch already scroll).
class ScrollFocusStop extends StatefulWidget {
  final Widget child;
  const ScrollFocusStop({super.key, required this.child});
  @override
  State<ScrollFocusStop> createState() => _ScrollFocusStopState();
}

class _ScrollFocusStopState extends State<ScrollFocusStop> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    if (!AbkBreakpoints.isTv) return widget.child;
    final c = context.c;
    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (Scrollable.maybeOf(context) != null) {
              Scrollable.ensureVisible(context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut);
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AbkSpace.s12),
        decoration: BoxDecoration(
          color: _focused ? c.surfaceElevated : Colors.transparent,
          borderRadius: AbkRadius.brSm,
          border: Border.all(
              color: _focused ? c.focusRing : Colors.transparent, width: 2),
        ),
        child: widget.child,
      ),
    );
  }
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

  void _onFocus(bool v) {
    setState(() => _focus = v);
    // TV/D-pad: when this element gains focus, scroll it into view if it lives
    // inside a scroll view (so no focused control can sit off-screen).
    if (v) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scrollable = Scrollable.maybeOf(context);
        if (scrollable != null) {
          Scrollable.ensureVisible(context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tv = AbkBreakpoints.isTv;
    // On TV, a focused item always grows slightly (motion is the strongest
    // "you are here" cue at couch distance), even when no artwork focusScale is
    // set. Off-TV keeps the opt-in focusScale only.
    final tvFocusScale = tv ? 1.06 : 1.0;
    final scale = (_pressed && !widget.disabled)
        ? 0.98
        : (_focus && !reduce
            ? (widget.focusScale != 1.0 ? widget.focusScale : tvFocusScale)
            : 1.0);

    Widget child = widget.builder(context, _states);

    // Focus treatment. On TV the ring must read even on top of a same-colour
    // (e.g. gold) primary button, so it is a HIGH-CONTRAST white outline plus a
    // coloured glow halo that spills onto the dark surround — unmistakable on
    // both dark cards and accent buttons. Off-TV keeps the on-brand gold ring.
    if (_focus) {
      child = Container(
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          boxShadow: reduce
              ? null
              : (tv
                  ? [
                      BoxShadow(
                          color: c.focusRing.withValues(alpha: 0.55),
                          blurRadius: 20,
                          spreadRadius: 1),
                      const BoxShadow(
                          color: Color(0x73000000),
                          blurRadius: 8,
                          spreadRadius: 0),
                    ]
                  : AbkElevation.focus),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: widget.radius,
          border: Border.all(
            color: tv ? Colors.white : c.focusRing,
            width: tv ? 3 : 2,
          ),
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
      focusNode: widget.focusNode,
      mouseCursor: widget.disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: _onFocus,
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
