import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Type ramp (Design §05). Two text families + one mono. IBM Plex Sans Arabic
/// is the product face (Arabic + Latin, one metric); Archivo is Latin display;
/// IBM Plex Mono is metadata/numbers. Arabic runs +2dp size and +0.35
/// line-height and is never letter-spaced or uppercased.
///
/// Fonts fall back to the platform stack when the Google fonts are not bundled;
/// the scale, weights and line-heights (which drive layout) are exact.
class AbkFonts {
  static const product = 'IBM Plex Sans Arabic';
  static const display = 'Archivo';
  static const mono = 'IBM Plex Mono';
  static const fallback = <String>[
    'IBM Plex Sans Arabic', '.SF Arabic', 'Geeza Pro', 'Segoe UI', 'system-ui',
  ];
  static const monoFallback = <String>['IBM Plex Mono', 'SF Mono', 'Menlo', 'monospace'];
}

/// Resolved text styles for a build (width class + script + colour).
class AbkTextStyles {
  final int _i; // 0 phone, 1 tablet, 2 desktop, 3 tv
  final bool arabic;
  final Color color;
  final Color muted;

  AbkTextStyles(WidthClass wc, {required this.arabic, required this.color, required this.muted})
      : _i = switch (wc) {
          WidthClass.compact => 0,
          WidthClass.medium => 1,
          WidthClass.expanded => 1,
          WidthClass.desktop => 2,
          WidthClass.wideDesktop => 2,
          WidthClass.tv => 3,
        };

  double _pick(List<double> v) => v[_i];

  TextStyle _s(
    List<double> sizes,
    List<double> heights, {
    required FontWeight weight,
    bool mono = false,
    bool display = false,
    double? tracking,
    Color? c,
  }) {
    var size = _pick(sizes);
    var lh = _pick(heights);
    double ratio = lh <= 0 ? 1.2 : lh / size;
    // Arabic: +2dp, +0.35 line-height ratio, product face for display too.
    if (arabic && !mono) {
      size += 2;
      ratio += 0.35;
    }
    final fam = mono
        ? AbkFonts.mono
        : (display && !arabic ? AbkFonts.display : AbkFonts.product);
    return TextStyle(
      fontFamily: fam,
      fontFamilyFallback: mono ? AbkFonts.monoFallback : AbkFonts.fallback,
      fontSize: size,
      height: ratio,
      fontWeight: weight,
      letterSpacing: arabic ? 0 : tracking,
      color: c ?? color,
    );
  }

  TextStyle get hero => _s([34, 44, 52, 68], [36, 46, 54, 72], weight: FontWeight.w700, display: true);
  TextStyle get pageTitle => _s([26, 30, 34, 44], [32, 38, 42, 52], weight: FontWeight.w700, display: true);
  TextStyle get sectionTitle => _s([18, 20, 22, 30], [24, 26, 28, 38], weight: FontWeight.w600, display: true);
  TextStyle get cardTitle => _s([14, 15, 15, 24], [19, 20, 20, 30], weight: FontWeight.w600);
  TextStyle get body => _s([15, 15, 16, 24], [24, 25, 26, 36], weight: FontWeight.w400);
  TextStyle get bodySecondary => body.copyWith(color: muted);
  TextStyle get metadata => _s([12, 12, 13, 20], [16, 17, 18, 26], weight: FontWeight.w500, mono: true, c: muted);
  TextStyle get caption => _s([12, 12, 13, 20], [17, 17, 18, 26], weight: FontWeight.w400, c: muted);
  TextStyle get button => _s([15, 15, 14, 26], [20, 20, 19, 32], weight: FontWeight.w600);
  TextStyle get playerControl => _s([13, 14, 14, 22], [17, 18, 18, 28], weight: FontWeight.w500, mono: true);
  TextStyle get navLabel => _s([11, 12, 13, 20], [14, 15, 16, 24],
      weight: FontWeight.w600, tracking: arabic ? 0 : 0.6);
}
