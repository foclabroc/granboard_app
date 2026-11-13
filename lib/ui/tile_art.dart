import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustration animée d'une tuile de l'accueil.
enum TileArt { cricket, match, practice, party, online, tournament, options }

/// Dessine l'illustration dans le coin droit de la tuile ; [t] tourne de 0 à
/// 1 en boucle (animation lente partagée par toutes les tuiles).
class TileArtPainter extends CustomPainter {
  final TileArt art;
  final Color color;
  final Animation<double> t;
  TileArtPainter(this.art, this.color, this.t) : super(repaint: t);

  double _r(int i, int k) =>
      ((math.sin(i * 91.3 + k * 47.7) * 43758.5453) % 1).abs();

  Paint _stroke(double w, double alpha) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    final a = t.value * 2 * math.pi;
    // Zone de dessin : carré à droite, débordant un peu
    final s = h * 0.92;
    final c = Offset(w - s * 0.42, h * 0.52);
    switch (art) {
      case TileArt.options:
        // Curseurs de réglage qui glissent + silhouettes de joueurs
        for (var i = 0; i < 3; i++) {
          final y = c.dy - s * 0.24 + i * s * 0.24;
          final x0 = c.dx - s * 0.5, x1 = c.dx + s * 0.25;
          canvas.drawLine(
              Offset(x0, y), Offset(x1, y), _stroke(s * 0.03, 0.28));
          final k = 0.5 + 0.42 * math.sin(a * 2 + i * 2.1);
          final kx = x0 + (x1 - x0) * k;
          canvas.drawLine(Offset(x0, y), Offset(kx, y), _stroke(s * 0.03, 0.6));
          canvas.drawCircle(Offset(kx, y), s * 0.055,
              Paint()..color = color.withValues(alpha: 0.75));
        }
      case TileArt.cricket:
        // Les 3 marques du Cricket : / , X , Ⓧ
        final u = s * 0.13;
        for (var i = 0; i < 3; i++) {
          final p = Offset(c.dx - s * 0.52 + i * s * 0.31,
              c.dy + s * 0.05 * math.sin(a * 4 + i * 1.4));
          final glow = 0.35 + 0.3 * (0.5 + 0.5 * math.sin(a * 4 - i * 1.4));
          final st = _stroke(s * 0.045, glow);
          canvas.drawLine(p + Offset(-u, u), p + Offset(u, -u), st);
          if (i >= 1) canvas.drawLine(p + Offset(-u, -u), p + Offset(u, u), st);
          if (i == 2) canvas.drawCircle(p, u * 1.45, st);
        }
      case TileArt.match:
        // Deux fléchettes croisées + éclat
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(side * (0.75 + 0.06 * math.sin(a * 3)));
          final st = _stroke(s * 0.035, 0.5);
          canvas.drawLine(Offset(0, -s * 0.42), Offset(0, s * 0.3), st);
          // pointe
          canvas.drawLine(
              Offset(0, s * 0.3), Offset(0, s * 0.44), _stroke(s * 0.012, 0.7));
          // ailettes
          final fl = Path()
            ..moveTo(0, -s * 0.44)
            ..lineTo(-s * 0.09, -s * 0.36)
            ..lineTo(-s * 0.09, -s * 0.24)
            ..lineTo(0, -s * 0.28)
            ..lineTo(s * 0.09, -s * 0.24)
            ..lineTo(s * 0.09, -s * 0.36)
            ..close();
          canvas.drawPath(fl, Paint()..color = color.withValues(alpha: 0.4));
          canvas.restore();
        }
        final pulse = 0.5 + 0.5 * math.sin(a * 6);
        canvas.drawCircle(
            c,
            s * (0.06 + 0.03 * pulse),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.35 + 0.3 * pulse)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03));
      case TileArt.practice:
        // Cible stylisée + viseur qui se promène
        for (var i = 1; i <= 4; i++) {
          canvas.drawCircle(
              c, s * 0.11 * i, _stroke(s * 0.018, 0.14 + 0.07 * i));
        }
        canvas.drawCircle(
            c, s * 0.035, Paint()..color = color.withValues(alpha: 0.8));
        final p =
            c + Offset(math.cos(a * 3) * s * 0.2, math.sin(a * 5) * s * 0.16);
        final st = _stroke(s * 0.02, 0.9)
          ..color = Colors.white.withValues(alpha: 0.75);
        canvas.drawCircle(p, s * 0.07, st);
        for (final d in const [
          Offset(1, 0),
          Offset(-1, 0),
          Offset(0, 1),
          Offset(0, -1)
        ]) {
          canvas.drawLine(p + d * s * 0.04, p + d * s * 0.11, st);
        }
      case TileArt.party:
        // Confettis qui tombent + ballons
        const cols = [
          Color(0xFFFFD23F),
          Color(0xFFFF5D8F),
          Color(0xFF3DDCFF),
          Color(0xFF7CFF6B),
          Color(0xFFFF9F45),
        ];
        for (var i = 0; i < 26; i++) {
          final speed = 1 + (i % 3);
          final y = ((_r(i, 1) + t.value * speed * 2) % 1) * (h + 20) - 10;
          final x = w * 0.35 + _r(i, 2) * w * 0.65;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(a * speed * 3 + i);
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset.zero, width: s * 0.05, height: s * 0.025),
              Paint()..color = cols[i % cols.length].withValues(alpha: 0.75));
          canvas.restore();
        }
        for (var i = 0; i < 2; i++) {
          final b = Offset(c.dx - s * 0.1 + i * s * 0.3,
              c.dy - s * 0.02 + s * 0.04 * math.sin(a * 3 + i * 2));
          canvas.drawLine(
              b + Offset(0, s * 0.17),
              b + Offset(s * 0.03, s * 0.5),
              _stroke(s * 0.008, 0.5)..color = Colors.white54);
          canvas.drawOval(
              Rect.fromCenter(center: b, width: s * 0.26, height: s * 0.32),
              Paint()..color = cols[i + 1].withValues(alpha: 0.55));
          canvas.drawOval(
              Rect.fromCenter(
                  center: b + Offset(-s * 0.05, -s * 0.07),
                  width: s * 0.06,
                  height: s * 0.09),
              Paint()..color = Colors.white.withValues(alpha: 0.35));
        }
      case TileArt.tournament:
        // Tableau à élimination : 4 joueurs → 2 → vainqueur, chemin lumineux
        final st = _stroke(s * 0.022, 0.4);
        final lit = _stroke(s * 0.03, 0.95);
        final x0 = c.dx - s * 0.55, x1 = c.dx - s * 0.2, x2 = c.dx + s * 0.15;
        final ys = [for (var i = 0; i < 4; i++) c.dy - s * 0.36 + i * s * 0.24];
        final y1 = [(ys[0] + ys[1]) / 2, (ys[2] + ys[3]) / 2];
        final yw = (y1[0] + y1[1]) / 2;
        // Le chemin qui s'allume change avec le temps
        final pick = (t.value * 4).floor() % 4;
        Path branch(double xa, double ya, double xb, double yb) => Path()
          ..moveTo(xa, ya)
          ..lineTo((xa + xb) / 2, ya)
          ..lineTo((xa + xb) / 2, yb)
          ..lineTo(xb, yb);
        for (var i = 0; i < 4; i++) {
          canvas.drawPath(
              branch(x0, ys[i], x1, y1[i ~/ 2]), i == pick ? lit : st);
          canvas.drawCircle(
              Offset(x0, ys[i]),
              s * 0.035,
              Paint()
                ..color = color.withValues(alpha: i == pick ? 0.95 : 0.45));
        }
        for (var i = 0; i < 2; i++) {
          canvas.drawPath(branch(x1, y1[i], x2, yw), i == pick ~/ 2 ? lit : st);
        }
        // Trophée au bout
        final tc = Offset(x2 + s * 0.17, yw);
        final cup = Path()
          ..moveTo(tc.dx - s * 0.11, tc.dy - s * 0.12)
          ..lineTo(tc.dx + s * 0.11, tc.dy - s * 0.12)
          ..quadraticBezierTo(
              tc.dx + s * 0.1, tc.dy + s * 0.04, tc.dx, tc.dy + s * 0.05)
          ..quadraticBezierTo(tc.dx - s * 0.1, tc.dy + s * 0.04,
              tc.dx - s * 0.11, tc.dy - s * 0.12)
          ..close();
        final glow = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(a * 4));
        canvas.drawPath(cup, Paint()..color = color.withValues(alpha: glow));
        canvas.drawRect(
            Rect.fromCenter(
                center: tc + Offset(0, s * 0.1),
                width: s * 0.04,
                height: s * 0.08),
            Paint()..color = color.withValues(alpha: glow));
        canvas.drawRect(
            Rect.fromCenter(
                center: tc + Offset(0, s * 0.15),
                width: s * 0.14,
                height: s * 0.035),
            Paint()..color = color.withValues(alpha: glow));
      case TileArt.online:
        // Globe + joueurs en orbite + ondes
        final r = s * 0.3;
        final st = _stroke(s * 0.016, 0.45);
        canvas.drawCircle(c, r, st);
        for (final k in const [0.35, 0.75]) {
          canvas.drawOval(
              Rect.fromCenter(center: c, width: r * 2 * k, height: r * 2), st);
        }
        canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), st);
        canvas.drawOval(
            Rect.fromCenter(
                center: c - Offset(0, r * 0.5),
                width: r * 1.72,
                height: r * 0.3),
            st);
        canvas.drawOval(
            Rect.fromCenter(
                center: c + Offset(0, r * 0.5),
                width: r * 1.72,
                height: r * 0.3),
            st);
        for (var i = 0; i < 2; i++) {
          final ang = a * 4 + i * math.pi;
          final p =
              c + Offset(math.cos(ang) * r * 1.45, math.sin(ang) * r * 0.55);
          canvas.drawCircle(
              p,
              s * 0.045,
              Paint()
                ..color = (i == 0 ? Colors.white : color).withValues(alpha: 0.9)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012));
        }
        final wave = (t.value * 8) % 1;
        canvas.drawCircle(
            c, r * (1 + wave * 0.6), _stroke(s * 0.012, 0.35 * (1 - wave)));
    }
  }

  @override
  bool shouldRepaint(TileArtPainter old) =>
      old.art != art || old.color != color;
}
