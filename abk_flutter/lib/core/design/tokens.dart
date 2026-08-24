import 'package:flutter/material.dart';

/// ABK Cinema design tokens — one semantic name set, two value sets
/// (Design §03/§04). Screens never hardcode a hex, size or duration.

/// Semantic colour set, carried as a [ThemeExtension] so it participates in
/// theme crossfades. Access via `context.c`.
@immutable
class AbkColors extends ThemeExtension<AbkColors> {
  final Color background, surface, surfaceElevated, surfaceStrong;
  final Color card, cardFocused;
  final Color accentPrimary, accentSecondary;
  final Color success, warning, error, info;
  final Color textPrimary, textSecondary, textMuted, textDisabled;
  final Color borderSubtle, divider, focusRing;
  final Color scrim, playerOverlay, skeletonBase, skeletonHi;
  final List<Color> placeholders;
  final bool isLight;
  final bool cardBorder; // light adds a 1px border to cards

  const AbkColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceStrong,
    required this.card,
    required this.cardFocused,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.borderSubtle,
    required this.divider,
    required this.focusRing,
    required this.scrim,
    required this.playerOverlay,
    required this.skeletonBase,
    required this.skeletonHi,
    required this.placeholders,
    required this.isLight,
    required this.cardBorder,
  });

  /// A stable placeholder colour for a title (hash(title)%3), so a title always
  /// looks the same (Design §03).
  Color placeholderFor(String key) =>
      placeholders[(key.hashCode & 0x7fffffff) % placeholders.length];

  static const dark = AbkColors(
    background: Color(0xFF0E0D0C),
    surface: Color(0xFF161413),
    surfaceElevated: Color(0xFF1D1A18),
    surfaceStrong: Color(0xFF272320),
    card: Color(0xFF201D1A),
    cardFocused: Color(0xFF2E2925),
    accentPrimary: Color(0xFFE8B14C),
    accentSecondary: Color(0xFFE8654C),
    success: Color(0xFF4FB07A),
    warning: Color(0xFFE39B2E),
    error: Color(0xFFE05252),
    info: Color(0xFF7FA6B8),
    textPrimary: Color(0xFFF5F1EC),
    textSecondary: Color(0xFFB5ADA4),
    textMuted: Color(0xFF857E76),
    textDisabled: Color(0xFF574F49),
    borderSubtle: Color(0xFF2C2724),
    divider: Color(0xFF3B3530),
    focusRing: Color(0xFFF0C777),
    scrim: Color(0xD1090808), // 82%
    playerOverlay: Color(0x24F5F1EC), // 14%
    skeletonBase: Color(0xFF1D1A18),
    skeletonHi: Color(0xFF2A2521),
    placeholders: [Color(0xFF2A2522), Color(0xFF332C27), Color(0xFF241F1C)],
    isLight: false,
    cardBorder: false,
  );

  static const light = AbkColors(
    background: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF6F1E9),
    surfaceStrong: Color(0xFFE8E1D6),
    card: Color(0xFFFFFFFF),
    cardFocused: Color(0xFFF2EDE5),
    accentPrimary: Color(0xFFA9721A),
    accentSecondary: Color(0xFFC24A2E),
    success: Color(0xFF2F8659),
    warning: Color(0xFFA66C10),
    error: Color(0xFFB23636),
    info: Color(0xFF3F6E85),
    textPrimary: Color(0xFF1A1715),
    textSecondary: Color(0xFF57504A),
    textMuted: Color(0xFF8A827A),
    textDisabled: Color(0xFFB6AEA6),
    borderSubtle: Color(0xFFE2DAD0),
    divider: Color(0xFFCFC5B8),
    focusRing: Color(0xFFA9721A),
    scrim: Color(0x8C1A1715), // 55%
    playerOverlay: Color(0x24F5F1EC),
    skeletonBase: Color(0xFFE8E1D6),
    skeletonHi: Color(0xFFF4EFE7),
    placeholders: [Color(0xFFE4DBCE), Color(0xFFDCD2C3), Color(0xFFEDE5D9)],
    isLight: true,
    cardBorder: true,
  );

  /// The "always dark" surface set for players/launch/login/fullscreen/TV.
  static const AbkColors player = dark;

  @override
  AbkColors copyWith() => this;

  @override
  AbkColors lerp(ThemeExtension<AbkColors>? other, double t) {
    if (other is! AbkColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AbkColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      surfaceStrong: l(surfaceStrong, other.surfaceStrong),
      card: l(card, other.card),
      cardFocused: l(cardFocused, other.cardFocused),
      accentPrimary: l(accentPrimary, other.accentPrimary),
      accentSecondary: l(accentSecondary, other.accentSecondary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      info: l(info, other.info),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      textDisabled: l(textDisabled, other.textDisabled),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      divider: l(divider, other.divider),
      focusRing: l(focusRing, other.focusRing),
      scrim: l(scrim, other.scrim),
      playerOverlay: l(playerOverlay, other.playerOverlay),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonHi: l(skeletonHi, other.skeletonHi),
      placeholders: t < 0.5 ? placeholders : other.placeholders,
      isLight: t < 0.5 ? isLight : other.isLight,
      cardBorder: t < 0.5 ? cardBorder : other.cardBorder,
    );
  }
}

/// Spacing scale (Design §03): 2 4 8 12 16 20 24 32 40 48 64 80.
class AbkSpace {
  static const double s2 = 2, s4 = 4, s8 = 8, s12 = 12, s16 = 16, s20 = 20;
  static const double s24 = 24, s32 = 32, s40 = 40, s48 = 48, s64 = 64, s80 = 80;
}

/// Corner radii (Design §03).
class AbkRadius {
  static const xs = Radius.circular(4);
  static const sm = Radius.circular(8);
  static const poster = Radius.circular(10);
  static const md = Radius.circular(12);
  static const modal = Radius.circular(16);
  static const lg = Radius.circular(20);
  static const sheet = Radius.circular(24);
  static const pill = Radius.circular(999);

  static const brXs = BorderRadius.all(xs);
  static const brSm = BorderRadius.all(sm);
  static const brPoster = BorderRadius.all(poster);
  static const brMd = BorderRadius.all(md);
  static const brLg = BorderRadius.all(lg);
  static const brPill = BorderRadius.all(pill);
}

/// Aspect ratios (Design §03).
class AbkAspect {
  static const poster = 2 / 3;
  static const backdrop = 16 / 9;
  static const channelLogo = 1.0;
  static const continueWatching = 16 / 9;
  static const categoryTile = 3 / 2;
  static const episodeThumb = 16 / 9;
}

/// Elevation (Design §03).
class AbkElevation {
  static List<BoxShadow> elev1 = const [
    BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static List<BoxShadow> elev2 = const [
    BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static List<BoxShadow> hover = const [
    BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static List<BoxShadow> focus = const [
    BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}

/// Motion (Design §06). One duration exceeds 320ms on purpose (overlay out).
class AbkMotion {
  static const fast = Duration(milliseconds: 120);
  static const hover = Duration(milliseconds: 140);
  static const focusMove = Duration(milliseconds: 160);
  static const searchIn = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 260);
  static const hero = Duration(milliseconds: 300);
  static const overlayOut = Duration(milliseconds: 320);
  static const shimmer = Duration(milliseconds: 1400);

  static const easeOut = Curves.easeOut;
  static const easeInOut = Curves.easeInOut;
  static const emphasized = Cubic(0.2, 0.8, 0.2, 1.0);
}
