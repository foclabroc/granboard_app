import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../granboard.dart';
import 'theme.dart';

/// Ordre des numéros dans le sens des aiguilles, en partant du haut.
const kBoardOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5 //
];

/// Cible dessinée, avec les zones touchées mises en lumière.
class Dartboard extends StatelessWidget {
  final double size;
  final List<DartHit> highlights;
  final bool showNumbers;
  const Dartboard({
    super.key,
    required this.size,
    this.highlights = const [],
    this.showNumbers = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BoardPainter(highlights, showNumbers),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<DartHit> highlights;
  final bool showNumbers;
  _BoardPainter(this.highlights, this.showNumbers);

  // Rayons relatifs (1 = bord extérieur de la zone des doubles)
  static const rDoubleOut = 1.0;
  static const rDoubleIn = 0.905;
  static const rTripleOut = 0.62;
  static const rTripleIn = 0.525;
  static const rBullOut = 0.094;
  static const rBullIn = 0.037;

  static const black = Color(0xFF121216);
  static const wire = Color(0xFF7D7D86);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final numbersBand = showNumbers ? outer * 0.15 : outer * 0.04;
    final r = outer - numbersBand;

    // Fond + anneau or
    canvas.drawCircle(c, outer, Paint()..color = const Color(0xFF0B0B0E));
    canvas.drawCircle(
        c,
        outer - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, outer * 0.025)
          ..color = Tv.gold);

    const seg = 2 * math.pi / 20;
    for (var i = 0; i < 20; i++) {
      final a0 = -math.pi / 2 - seg / 2 + i * seg;
      final even = i % 2 == 0;
      final single = even ? black : Tv.cream;
      final ring = even ? Tv.red : Tv.green;
      _wedge(canvas, c, r * rDoubleIn, r * rTripleOut, a0, seg, single);
      _wedge(canvas, c, r * rTripleIn, r * rBullOut, a0, seg, single);
      _wedge(canvas, c, r * rDoubleOut, r * rDoubleIn, a0, seg, ring);
      _wedge(canvas, c, r * rTripleOut, r * rTripleIn, a0, seg, ring);
    }
    canvas.drawCircle(c, r * rBullOut, Paint()..color = Tv.green);
    canvas.drawCircle(c, r * rBullIn, Paint()..color = Tv.red);

    // Fils
    final wirePaint = Paint()
      ..color = wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.006);
    for (final rr in [rDoubleOut, rDoubleIn, rTripleOut, rTripleIn, rBullOut]) {
      canvas.drawCircle(c, r * rr, wirePaint);
    }
    for (var i = 0; i < 20; i++) {
      final a = -math.pi / 2 - seg / 2 + i * seg;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * rBullOut,
          c + Offset(math.cos(a), math.sin(a)) * r, wirePaint);
    }

    // Zones touchées (halo lumineux)
    for (var k = 0; k < highlights.length; k++) {
      _highlight(canvas, c, r, highlights[k], k);
    }

    // Numéros
    if (showNumbers) {
      for (var i = 0; i < 20; i++) {
        final n = kBoardOrder[i];
        final hit = highlights.any((h) => h.number == n);
        final a = -math.pi / 2 + i * seg;
        final pos =
            c + Offset(math.cos(a), math.sin(a)) * (r + numbersBand / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: '$n',
            style: TextStyle(
              fontFamily: Tv.font,
              fontWeight: FontWeight.w800,
              fontSize: numbersBand * 0.78,
              color: hit ? Tv.goldLight : Tv.text,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _highlight(Canvas canvas, Offset c, double r, DartHit h, int order) {
    final glow = Paint()
      ..color = Tv.goldLight
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, math.max(2, r * 0.03));
    final edge = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, r * 0.018);

    if (h.isBull) {
      final rr = h.ring == Ring.innerBull ? rBullIn : rBullOut;
      canvas.drawCircle(c, r * rr, glow);
      canvas.drawCircle(c, r * rr, edge);
      _badge(canvas, c, r, order);
      return;
    }
    final i = kBoardOrder.indexOf(h.number);
    if (i < 0) return;
    const seg = 2 * math.pi / 20;
    final a0 = -math.pi / 2 - seg / 2 + i * seg;
    final (ro, ri) = switch (h.ring) {
      Ring.double => (rDoubleOut, rDoubleIn),
      Ring.triple => (rTripleOut, rTripleIn),
      Ring.singleOuter => (rDoubleIn, rTripleOut),
      _ => (rTripleIn, rBullOut),
    };
    final path = _wedgePath(c, r * ro, r * ri, a0, seg);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, edge);
    final mid = a0 + seg / 2;
    final p = c + Offset(math.cos(mid), math.sin(mid)) * r * (ro + ri) / 2;
    _badge(canvas, p, r, order);
  }

  /// Petit numéro de fléchette (1, 2, 3) posé sur la zone.
  void _badge(Canvas canvas, Offset p, double r, int order) {
    final br = math.max(9.0, r * 0.1);
    canvas.drawCircle(p, br, Paint()..color = Colors.black);
    canvas.drawCircle(
        p,
        br,
        Paint()
          ..color = Tv.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, br * 0.18));
    final tp = TextPainter(
      text: TextSpan(
          text: '${order + 1}',
          style: TextStyle(
              fontFamily: Tv.font,
              fontWeight: FontWeight.w800,
              fontSize: br * 1.3,
              color: Tv.goldLight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  Path _wedgePath(Offset c, double ro, double ri, double a0, double sweep) {
    return Path()
      ..arcTo(Rect.fromCircle(center: c, radius: ro), a0, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: ri), a0 + sweep, -sweep, false)
      ..close();
  }

  void _wedge(Canvas canvas, Offset c, double ro, double ri, double a0,
      double sweep, Color color) {
    canvas.drawPath(_wedgePath(c, ro, ri, a0, sweep), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.highlights != highlights || old.showNumbers != showNumbers;
}

// ─── Cible animée (écran de partie) ───────────────────────────────────────

/// Point d'impact d'une fléchette (centre de la zone + léger décalage stable).
Offset dartPoint(Offset c, double r, DartHit h, int order) {
  if (h.isBull) {
    final rr = h.ring == Ring.innerBull ? 0.02 : 0.066;
    final a = order * 2.1;
    return c + Offset(math.cos(a), math.sin(a)) * r * rr;
  }
  final i = kBoardOrder.indexOf(h.number);
  const seg = 2 * math.pi / 20;
  final (ro, ri) = switch (h.ring) {
    Ring.double => (_BoardPainter.rDoubleOut, _BoardPainter.rDoubleIn),
    Ring.triple => (_BoardPainter.rTripleOut, _BoardPainter.rTripleIn),
    Ring.singleOuter => (_BoardPainter.rDoubleIn, _BoardPainter.rTripleOut),
    _ => (_BoardPainter.rTripleIn, _BoardPainter.rBullOut),
  };
  // Décalage pour que 3 fléchettes dans la même zone ne se cachent pas
  final jitterA = (order - 1) * seg * 0.22;
  final a = -math.pi / 2 + i * seg + jitterA;
  final rr = (ro + ri) / 2 + (order.isEven ? -1 : 1) * (ro - ri) * 0.12;
  return c + Offset(math.cos(a), math.sin(a)) * r * rr;
}

/// Grande cible de la partie : zones touchées qui pulsent, impact animé
/// (onde + fléchette qui se plante), éclair rouge sur un bust.
class AnimatedDartboard extends StatefulWidget {
  final double size;
  final List<DartHit> hits;
  final bool bust;
  final bool win;
  final Color dartColor;
  const AnimatedDartboard({
    super.key,
    required this.size,
    required this.hits,
    this.bust = false,
    this.win = false,
    this.dartColor = Tv.gold,
  });

  @override
  State<AnimatedDartboard> createState() => _AnimatedDartboardState();
}

class _AnimatedDartboardState extends State<AnimatedDartboard>
    with TickerProviderStateMixin {
  late final _impact = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(AnimatedDartboard old) {
    super.didUpdateWidget(old);
    if (widget.hits.length > old.hits.length) _impact.forward(from: 0);
    if (widget.bust && !old.bust) _flash.forward(from: 0);
    if (widget.win && !old.win) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _impact.dispose();
    _pulse.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BoardPainter(const [], true),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_impact, _pulse, _flash]),
                builder: (context, _) => CustomPaint(
                  painter: _HitsPainter(
                    hits: widget.hits,
                    impact: _impact.value,
                    pulse: _pulse.value,
                    flash: _flash.value,
                    flashColor: widget.win ? Tv.gold : Tv.red,
                    dartColor: widget.dartColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitsPainter extends CustomPainter {
  final List<DartHit> hits;
  final double impact; // 0 → 1 pour la dernière fléchette
  final double pulse;
  final double flash;
  final Color flashColor;
  final Color dartColor;
  _HitsPainter({
    required this.hits,
    required this.impact,
    required this.pulse,
    required this.flash,
    required this.flashColor,
    required this.dartColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final r = outer - outer * 0.15; // même calcul que _BoardPainter

    // Zones touchées : halo qui pulse
    for (var k = 0; k < hits.length; k++) {
      final last = k == hits.length - 1;
      final path = _zonePath(c, r, hits[k]);
      final glow = 0.55 + 0.35 * pulse + (last ? 0.1 * (1 - impact) : 0);
      canvas.drawPath(
          path,
          Paint()
            ..color = Tv.goldLight.withValues(alpha: glow.clamp(0, 1))
            ..maskFilter = MaskFilter.blur(BlurStyle.solid, r * 0.03));
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.02);
    }

    // Onde de choc de la dernière fléchette
    if (hits.isNotEmpty && impact < 1) {
      final p = dartPoint(c, r, hits.last, hits.length);
      final t = Curves.easeOut.transform(impact);
      canvas.drawCircle(
          p,
          r * (0.05 + 0.4 * t),
          Paint()
            ..color = Tv.goldLight.withValues(alpha: (1 - t) * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.025 * (1 - t) + 1);
    }

    // Fléchettes plantées (vues de face : empennage en croix)
    for (var k = 0; k < hits.length; k++) {
      final last = k == hits.length - 1;
      final p = dartPoint(c, r, hits[k], k + 1);
      // La dernière arrive de loin : plus grosse puis se plante
      final t = last ? Curves.easeIn.transform(impact.clamp(0, 1)) : 1.0;
      final scale = 1 + (1 - t) * 1.6;
      final s = r * 0.085 * scale;
      final shadowOff = const Offset(1, 1) * r * 0.03 * scale;
      canvas.drawCircle(p + shadowOff, s * 0.9,
          Paint()..color = Colors.black.withValues(alpha: 0.45));
      final flight = Paint()..color = dartColor;
      for (var q = 0; q < 4; q++) {
        final a = math.pi / 4 + q * math.pi / 2;
        final dir = Offset(math.cos(a), math.sin(a));
        final side = Offset(-dir.dy, dir.dx);
        canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy)
              ..lineTo((p + dir * s + side * s * 0.35).dx,
                  (p + dir * s + side * s * 0.35).dy)
              ..lineTo((p + dir * s - side * s * 0.35).dx,
                  (p + dir * s - side * s * 0.35).dy)
              ..close(),
            flight);
      }
      canvas.drawCircle(p, s * 0.28, Paint()..color = Colors.black);
      canvas.drawCircle(
          p,
          s * 0.28,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, s * 0.08));
    }

    // Éclair plein écran (bust en rouge, victoire en or)
    if (flash > 0 && flash < 1) {
      final a = math.sin(flash * math.pi) * 0.45;
      canvas.drawCircle(
          c, outer, Paint()..color = flashColor.withValues(alpha: a));
    }
  }

  Path _zonePath(Offset c, double r, DartHit h) {
    if (h.isBull) {
      final rr = h.ring == Ring.innerBull
          ? _BoardPainter.rBullIn
          : _BoardPainter.rBullOut;
      return Path()..addOval(Rect.fromCircle(center: c, radius: r * rr));
    }
    final i = kBoardOrder.indexOf(h.number);
    const seg = 2 * math.pi / 20;
    final a0 = -math.pi / 2 - seg / 2 + i * seg;
    final (ro, ri) = switch (h.ring) {
      Ring.double => (_BoardPainter.rDoubleOut, _BoardPainter.rDoubleIn),
      Ring.triple => (_BoardPainter.rTripleOut, _BoardPainter.rTripleIn),
      Ring.singleOuter => (_BoardPainter.rDoubleIn, _BoardPainter.rTripleOut),
      _ => (_BoardPainter.rTripleIn, _BoardPainter.rBullOut),
    };
    return Path()
      ..arcTo(Rect.fromCircle(center: c, radius: r * ro), a0, seg, true)
      ..arcTo(Rect.fromCircle(center: c, radius: r * ri), a0 + seg, -seg, false)
      ..close();
  }

  @override
  bool shouldRepaint(_HitsPainter old) => true;
}
