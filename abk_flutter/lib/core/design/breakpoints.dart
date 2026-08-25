import 'package:flutter/widgets.dart';

/// Adaptive width classes (Design §02). A D-pad primary input forces [tv]
/// at any width.
enum WidthClass { compact, medium, expanded, desktop, wideDesktop, tv }

class AbkBreakpoints {
  static const double medium = 600;
  static const double expanded = 905;
  static const double desktop = 1280;
  static const double wide = 1728;
  static const Size minWindow = Size(880, 620);
  static const double contentMax = 1680;

  static WidthClass resolve(double width, {bool tv = false}) {
    if (tv) return WidthClass.tv;
    if (width < medium) return WidthClass.compact;
    if (width < expanded) return WidthClass.medium;
    if (width < desktop) return WidthClass.expanded;
    if (width < wide) return WidthClass.desktop;
    return WidthClass.wideDesktop;
  }

  /// Set once at bootstrap when the app runs on an Android TV / Google TV
  /// (leanback) device. Forces the [WidthClass.tv] 10-foot presentation
  /// everywhere, regardless of the (often 1080p/4K) window width.
  static bool isTv = false;

  static WidthClass of(BuildContext context) =>
      resolve(MediaQuery.sizeOf(context).width, tv: isTv);

  /// TV is treated as a large desktop-class screen (grids, split/three-pane,
  /// sidebar) so the UI adapts structurally rather than scaling a phone.
  static bool isDesktopClass(WidthClass c) =>
      c == WidthClass.tv || c == WidthClass.desktop || c == WidthClass.wideDesktop;
  static bool usesSidebar(WidthClass c) =>
      c == WidthClass.tv ||
      c == WidthClass.desktop ||
      c == WidthClass.wideDesktop ||
      c == WidthClass.expanded;
  static bool usesBottomBar(WidthClass c) =>
      c == WidthClass.compact || c == WidthClass.medium;

  static double contentMargin(WidthClass c) => switch (c) {
        WidthClass.compact => 16,
        WidthClass.medium => 24,
        WidthClass.expanded => 32,
        WidthClass.desktop => 40,
        WidthClass.wideDesktop => 40,
        WidthClass.tv => 64,
      };

  static double gridGap(WidthClass c) => switch (c) {
        WidthClass.compact => 8,
        WidthClass.medium => 12,
        WidthClass.expanded => 16,
        WidthClass.desktop => 20,
        WidthClass.wideDesktop => 20,
        WidthClass.tv => 24,
      };

  static double sectionGap(WidthClass c) => switch (c) {
        WidthClass.compact => 32,
        WidthClass.medium => 36,
        WidthClass.expanded => 40,
        WidthClass.desktop => 48,
        WidthClass.wideDesktop => 48,
        WidthClass.tv => 56,
      };

  static double posterWidth(WidthClass c) => switch (c) {
        WidthClass.compact => 108,
        WidthClass.medium => 132,
        WidthClass.expanded => 150,
        WidthClass.desktop => 164,
        WidthClass.wideDesktop => 164,
        WidthClass.tv => 228,
      };

  static int posterColumns(WidthClass c) => switch (c) {
        WidthClass.compact => 3,
        WidthClass.medium => 5,
        WidthClass.expanded => 6,
        WidthClass.desktop => 7,
        WidthClass.wideDesktop => 8,
        WidthClass.tv => 7,
      };

  static double minHitTarget(WidthClass c) =>
      c == WidthClass.tv ? 64 : (isDesktopClass(c) ? 32 : 48);
}
