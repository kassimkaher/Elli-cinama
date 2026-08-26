import 'package:flutter/material.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import 'focusable.dart';

/// A fully D-pad-navigable on-screen keyboard for Android TV.
///
/// The system leanback IME is not reliably navigable inside a Flutter view on
/// some TV hardware (e.g. TCL): the app window keeps key focus, so the remote's
/// D-pad never reaches the IME and BACK pops the route (exiting the app) instead
/// of dismissing the keyboard. This in-app keyboard sidesteps that entirely: it
/// is a grid of real focus targets, types into the bound controller, and — being
/// a bottom-sheet route — BACK simply closes it and returns to the field.
///
/// Shown via [showTvKeyboard]; only used on TV (phones/desktop keep the system
/// keyboard).
Future<void> showTvKeyboard(
  BuildContext context,
  TextEditingController controller, {
  bool obscure = false,
  String title = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _TvKeyboard(controller: controller, obscure: obscure, title: title),
  );
}

class _TvKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final bool obscure;
  final String title;
  const _TvKeyboard({required this.controller, required this.obscure, required this.title});
  @override
  State<_TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<_TvKeyboard> {
  bool _upper = false;

  static const _rows = <List<String>>[
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '@'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', '_', '-'],
  ];

  void _insert(String s) {
    final t = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final next = t.replaceRange(start, end, s);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + s.length),
    );
  }

  void _backspace() {
    final t = widget.controller.text;
    if (t.isEmpty) return;
    final sel = widget.controller.selection;
    if (sel.isValid && sel.start != sel.end) {
      widget.controller.value = TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, ''),
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }
    final pos = sel.isValid ? sel.start : t.length;
    if (pos <= 0) return;
    widget.controller.value = TextEditingValue(
      text: t.replaceRange(pos - 1, pos, ''),
      selection: TextSelection.collapsed(offset: pos - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.borderSubtle)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Live preview of what is being typed (dots when obscured).
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (_, v, __) {
                final shown = widget.obscure
                    ? '•' * v.text.length
                    : (v.text.isEmpty ? (widget.title) : v.text);
                return Row(children: [
                  Icon(Icons.keyboard_rounded, size: 18, color: c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(shown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.body.copyWith(
                            color: v.text.isEmpty ? c.textMuted : c.textPrimary)),
                  ),
                ]);
              },
            ),
          ),
          for (var r = 0; r < _rows.length; r++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in _rows[r])
                  _Key(
                    label: _upper && _isLetter(k) ? k.toUpperCase() : k,
                    autofocus: r == 0 && k == '1',
                    onTap: () => _insert(_upper && _isLetter(k) ? k.toUpperCase() : k),
                  ),
              ],
            ),
          // Function row.
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Key(
              label: _upper ? 'ABC' : 'abc',
              icon: Icons.keyboard_capslock_rounded,
              wide: true,
              onTap: () => setState(() => _upper = !_upper),
            ),
            _Key(label: '', icon: Icons.space_bar_rounded, flex: true, onTap: () => _insert(' ')),
            _Key(label: '', icon: Icons.backspace_rounded, wide: true, onTap: _backspace),
            _Key(
              label: context.tr('done'),
              icon: Icons.check_rounded,
              wide: true,
              filled: true,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ]),
        ]),
      ),
    );
  }

  bool _isLetter(String s) => s.length == 1 && RegExp(r'[a-z]').hasMatch(s);
}

class _Key extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool autofocus;
  final bool wide; // fixed wider key (function keys)
  final bool flex; // fill remaining width (space bar)
  final bool filled; // accent (Done)
  const _Key({
    required this.label,
    required this.onTap,
    this.icon,
    this.autofocus = false,
    this.wide = false,
    this.flex = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final key = AbkFocusable(
      onTap: onTap,
      autofocus: autofocus,
      radius: AbkRadius.brSm,
      semanticLabel: label,
      builder: (ctx, states) {
        final focused = states.contains(WidgetState.focused);
        return Container(
          height: 52,
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? c.accentPrimary
                : (focused ? c.surfaceStrong : c.surfaceElevated),
            borderRadius: AbkRadius.brSm,
          ),
          child: icon != null
              ? Icon(icon, size: 22, color: filled ? c.background : c.textPrimary)
              : Text(label,
                  style: context.type.cardTitle
                      .copyWith(color: filled ? c.background : c.textPrimary)),
        );
      },
    );
    if (flex) return Expanded(child: key);
    if (wide) return SizedBox(width: 92, child: key);
    return SizedBox(width: 58, child: key);
  }
}
