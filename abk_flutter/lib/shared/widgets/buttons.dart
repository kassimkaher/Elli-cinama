import 'package:flutter/material.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import 'focusable.dart';

enum AbkButtonKind { primary, secondary, ghost, destructive }

class AbkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AbkButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool autofocus;

  const AbkButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = AbkButtonKind.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final disabled = onPressed == null || loading;
    late Color bg, fg, border;
    switch (kind) {
      case AbkButtonKind.primary:
        bg = c.accentPrimary; fg = c.background; border = Colors.transparent;
      case AbkButtonKind.secondary:
        bg = c.surfaceStrong; fg = c.textPrimary; border = c.borderSubtle;
      case AbkButtonKind.ghost:
        bg = Colors.transparent; fg = c.textPrimary; border = c.divider;
      case AbkButtonKind.destructive:
        bg = c.accentSecondary; fg = Colors.white; border = Colors.transparent;
    }
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: AbkFocusable(
        onTap: disabled ? null : onPressed,
        disabled: disabled,
        radius: AbkRadius.brSm,
        autofocus: autofocus,
        semanticLabel: label,
        builder: (ctx, states) {
          final hovered = states.contains(WidgetState.hovered) && !disabled;
          return AnimatedContainer(
            duration: AbkMotion.fast,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AbkSpace.s20, vertical: 13),
            decoration: BoxDecoration(
              color: hovered ? Color.alphaBlend(Colors.white.withValues(alpha: 0.06), bg) : bg,
              borderRadius: AbkRadius.brSm,
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Flexible(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: context.type.button.copyWith(color: fg)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AbkTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label, hint;
  final bool readOnly, obscure, autofocus;
  final Widget? trailing;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;

  const AbkTextField({
    super.key,
    this.controller,
    this.label = '',
    this.hint = '',
    this.readOnly = false,
    this.obscure = false,
    this.autofocus = false,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: context.type.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          obscureText: obscure,
          autofocus: autofocus,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: context.type.body,
          cursorColor: c.accentPrimary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.type.body.copyWith(color: c.textMuted),
            filled: true,
            fillColor: c.surfaceElevated,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: trailing,
            enabledBorder: OutlineInputBorder(
                borderRadius: AbkRadius.brSm, borderSide: BorderSide(color: c.borderSubtle)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AbkRadius.brSm, borderSide: BorderSide(color: c.accentPrimary, width: 2)),
            border: OutlineInputBorder(borderRadius: AbkRadius.brSm, borderSide: BorderSide(color: c.borderSubtle)),
          ),
        ),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label, hint, showLabel, hideLabel;
  final bool readOnly;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged, onSubmitted;
  const PasswordField({
    super.key,
    required this.controller,
    this.label = '',
    this.hint = '',
    this.showLabel = 'Show',
    this.hideLabel = 'Hide',
    this.readOnly = false,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    return AbkTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      label: widget.label,
      hint: widget.hint,
      obscure: !_show,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      trailing: IconButton(
        tooltip: _show ? widget.hideLabel : widget.showLabel,
        icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20, color: context.c.textMuted),
        onPressed: () => setState(() => _show = !_show),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;
  const SearchField({
    super.key,
    required this.controller,
    this.hint = '',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      style: context.type.body,
      cursorColor: c.accentPrimary,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: context.type.body.copyWith(color: c.textMuted),
        prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
                onPressed: onClear),
        filled: true,
        fillColor: c.surfaceElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: AbkRadius.brPill, borderSide: BorderSide(color: c.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: AbkRadius.brPill, borderSide: BorderSide(color: c.borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: AbkRadius.brPill, borderSide: BorderSide(color: c.accentPrimary, width: 2)),
      ),
    );
  }
}

class FilterChipRow<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  const FilterChipRow({super.key, required this.options, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final (v, label) = options[i];
          final sel = v == selected;
          return AbkFocusable(
            onTap: () => onSelected(v),
            radius: AbkRadius.brPill,
            selected: sel,
            builder: (ctx, s) => Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: sel ? c.accentPrimary : c.surfaceElevated,
                borderRadius: AbkRadius.brPill,
                border: Border.all(color: sel ? c.accentPrimary : c.borderSubtle),
              ),
              child: Text(label,
                  style: context.type.navLabel
                      .copyWith(color: sel ? c.background : c.textSecondary, letterSpacing: 0)),
            ),
          );
        },
      ),
    );
  }
}

/// Simple sort selector (Design §40 pattern) — only real, backable fields.
class SortSelector<T> extends StatelessWidget {
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String title;
  const SortSelector({super.key, required this.options, required this.selected, required this.onSelected, this.title = 'Sort'});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopupMenuButton<T>(
      initialValue: selected,
      color: c.surfaceElevated,
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        for (final (v, label) in options)
          PopupMenuItem(value: v, child: Text(label, style: context.type.body)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: c.surfaceElevated, borderRadius: AbkRadius.brSm, border: Border.all(color: c.borderSubtle)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sort_rounded, size: 16, color: c.textSecondary),
          const SizedBox(width: 6),
          Text(title, style: context.type.navLabel.copyWith(color: c.textSecondary, letterSpacing: 0)),
        ]),
      ),
    );
  }
}

/// PIN input for the parental lock (Design §61).
class PinInput extends StatelessWidget {
  final int length;
  final String value;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  const PinInput({
    super.key,
    this.length = 4,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.autofocus = true,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(alignment: Alignment.center, children: [
      Opacity(
        opacity: 0,
        child: SizedBox(
          width: 1, height: 1,
          child: TextField(
            focusNode: focusNode,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            maxLength: length,
            onChanged: onChanged,
            controller: TextEditingController.fromValue(
                TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length))),
          ),
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(length, (i) {
          final filled = i < value.length;
          return Container(
            width: 44, height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: AbkRadius.brSm,
              border: Border.all(color: filled ? c.accentPrimary : c.borderSubtle, width: filled ? 2 : 1),
            ),
            child: Text(filled ? '•' : '', style: context.type.pageTitle.copyWith(color: c.textPrimary)),
          );
        }),
      ),
    ]);
  }
}
