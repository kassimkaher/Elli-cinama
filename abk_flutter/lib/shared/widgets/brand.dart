import 'package:flutter/material.dart';

import '../../core/design/theme.dart';

/// ABK brand mark — an original, generic geometric mark: a **play triangle**
/// (cinema / streaming) led by a **motion chevron** (sports / speed). Drawn as a
/// vector via [CustomPaint] so it stays crisp at any size and reads on dark
/// surfaces. The same mark is used for the app icon (see tools that generate the
/// launcher PNGs) and in-app, keeping the brand consistent.
///
/// Two treatments:
/// * [AbkLogo.chip] — accent tile + dark mark (matches the app's chip aesthetic
///   on dark UI; high contrast).
/// * [AbkLogo.mark] — the mark alone on a transparent background (for larger
///   brand moments over dark surfaces).
class AbkLogo extends StatelessWidget {
  final double size;
  final Color? markColor;
  final Color? tileColor; // null → no tile

  const AbkLogo({super.key, this.size = 40, this.markColor, this.tileColor});

  /// Accent-gold tile with a dark mark — the in-app chip.
  const AbkLogo.chip({super.key, this.size = 40})
      : markColor = null,
        tileColor = null;

  /// Just the mark (defaults to accent gold), transparent background.
  const AbkLogo.mark({super.key, this.size = 40, Color? color})
      : markColor = color,
        tileColor = _transparent;

  static const _transparent = Color(0x00000000);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color mark;
    final Color? tile;
    if (tileColor == _transparent) {
      tile = null;
      mark = markColor ?? c.accentPrimary;
    } else {
      tile = tileColor ?? c.accentPrimary;
      mark = markColor ?? c.background;
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AbkMarkPainter(mark: mark, tile: tile),
        isComplex: false,
        willChange: false,
      ),
    );
  }
}

class _AbkMarkPainter extends CustomPainter {
  final Color mark;
  final Color? tile;
  _AbkMarkPainter({required this.mark, required this.tile});

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    Offset p(double x, double y) => Offset(x * u, y * u);

    if (tile != null) {
      final rr = RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(u * 0.26));
      final bg = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tile!, Color.lerp(tile!, Colors.black, 0.30)!],
        ).createShader(Offset.zero & size);
      canvas.drawRRect(rr, bg);
    }

    // Motion chevron ">" — speed / sports energy.
    final chevron = Path()
      ..moveTo(p(0.19, 0.30).dx, p(0.19, 0.30).dy)
      ..lineTo(p(0.35, 0.50).dx, p(0.35, 0.50).dy)
      ..lineTo(p(0.19, 0.70).dx, p(0.19, 0.70).dy);
    canvas.drawPath(
      chevron,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = mark.withValues(alpha: 0.60),
    );

    // Play triangle — cinema / streaming. Rounded joints via a stroked outline.
    final tri = Path()
      ..moveTo(p(0.45, 0.26).dx, p(0.45, 0.26).dy)
      ..lineTo(p(0.45, 0.74).dx, p(0.45, 0.74).dy)
      ..lineTo(p(0.81, 0.50).dx, p(0.81, 0.50).dy)
      ..close();
    canvas.drawPath(tri, Paint()..color = mark);
    canvas.drawPath(
      tri,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.05
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = mark,
    );
  }

  @override
  bool shouldRepaint(covariant _AbkMarkPainter o) =>
      o.mark != mark || o.tile != tile;
}

/// Mark + "ABK" wordmark row (sidebar / launch brand).
class AbkWordmark extends StatelessWidget {
  final double markSize;
  final bool chip;
  const AbkWordmark({super.key, this.markSize = 34, this.chip = true});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip ? AbkLogo.chip(size: markSize) : AbkLogo.mark(size: markSize),
          const SizedBox(width: 10),
          Text('ABK', style: context.type.sectionTitle),
        ],
      );
}
