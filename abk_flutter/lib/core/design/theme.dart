import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'tokens.dart';
import 'typography.dart';

ThemeData _build(AbkColors c) {
  final base = c.isLight ? const ColorScheme.light() : const ColorScheme.dark();
  final scheme = base.copyWith(
    primary: c.accentPrimary,
    onPrimary: c.background,
    secondary: c.accentSecondary,
    onSecondary: c.background,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceStrong,
    error: c.error,
    onError: c.isLight ? Colors.white : c.background,
    outline: c.divider,
    outlineVariant: c.borderSubtle,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    fontFamily: AbkFonts.product,
    fontFamilyFallback: AbkFonts.fallback,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    dividerColor: c.divider,
    iconTheme: IconThemeData(color: c.textPrimary),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.divider),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(6),
    ),
  );
}

class AbkTheme {
  static ThemeData dark() => _build(AbkColors.dark);
  static ThemeData light() => _build(AbkColors.light);
}

/// Wraps a subtree in the always-dark surface set (players, launch, login,
/// fullscreen, TV) regardless of the app theme (Design §04).
class AlwaysDark extends StatelessWidget {
  final Widget child;
  const AlwaysDark({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Theme(data: AbkTheme.dark(), child: child);
}

extension AbkContext on BuildContext {
  AbkColors get c => Theme.of(this).extension<AbkColors>() ?? AbkColors.dark;
  WidthClass get wc => AbkBreakpoints.of(this);
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  AbkTextStyles get type => AbkTextStyles(
        wc,
        arabic: isRtl,
        color: c.textPrimary,
        muted: c.textSecondary,
      );
}
