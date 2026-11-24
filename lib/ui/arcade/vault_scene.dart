// Coffre-fort : porte blindée, molette qui tourne à chaque fléchette,
// afficheur du code ; ouverture (porte qui pivote, lingots) ou alarme
// (gyrophare rouge).

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class VaultScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const VaultScene({super.key, required this.game, required this.colorOf});
  @override
  State<VaultScene> createState() => _VaultSceneState();
}

class _VaultSceneState extends State<VaultScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _dial = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _open = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _alarm = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  double _angle = 0, _angleFrom = 0, _angleTo = 0;

  int get _left => game.stateOf(game.current).v['left'] ?? 0;
  int get _code => game.stateOf(game.current).v['code'] ?? 0;

  @override
  void initState() {
    super.initState();
    startAmbient();
    _dial.addListener(() => _angle = _angleFrom +
        (_angleTo - _angleFrom) * Curves.easeOutBack.transform(_dial.value));
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    final p = e['p'] as int? ?? game.current;
    _angleFrom = _angle;
    _angleTo = _angle +
        pi *
            (0.6 + Random().nextDouble() * 0.8) *
            (Random().nextBool() ? 1 : -1);
    _dial.forward(from: 0);
    switch (e['type']) {
      case 'open':
        _open.forward(from: 0);
        _pops.currentState?.add(Pop('+\$${e['code']}', const Color(0xFFFFD34F),
            const Offset(0.42, 0.45),
            size: 54));
      case 'alarm':
        _alarm.forward(from: 0);
        _pops.currentState
            ?.add(Pop('ALARME !', Tv.red, const Offset(0.42, 0.45), size: 46));
      case 'turn':
        _pops.currentState?.add(Pop(
            '${e['left']}', widget.colorOf(p), const Offset(0.42, 0.3),
            size: 30));
    }
  }

  @override
  void dispose() {
    _dial.dispose();
    _open.dispose();
    _alarm.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final t = g.currentTurn;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_dial, _open, _alarm, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _VaultPainter(
                angle: _angle,
                left: _left,
                code: _code,
                open: _open.isAnimating ? _open.value : 0,
                alarm: _alarm.isAnimating ? _alarm.value : 0,
                t: ambient.value,
                round: g.round,
                rounds: g.roundLimit ?? 10,
                darts: [
                  for (final d in t.darts)
                    if (d.hit != null) d.hit!.label else 'RATÉ'
                ],
                color: widget.colorOf(g.current),
              ),
            ),
          ),
        ),
        Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: ScoreStrip(game: g, colorOf: widget.colorOf, sub: g.infoOf)),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _VaultPainter extends CustomPainter {
  final double angle, open, alarm, t;
  final int left, code, round, rounds;
  final List<String> darts;
  final Color color;
  _VaultPainter(
      {required this.angle,
      required this.left,
      required this.code,
      required this.open,
      required this.alarm,
      required this.t,
      required this.round,
      required this.rounds,
      required this.darts,
      required this.color});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // mur de la salle des coffres
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1C1A14), Color(0xFF0A0906)],
          ).createShader(Offset.zero & s));
    final brick = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke;
    for (var y = 0.0; y < h; y += 26) {
      final off = (y ~/ 26).isEven ? 0.0 : 30.0;
      for (var x = -off; x < w; x += 60) {
        c.drawRect(Rect.fromLTWH(x, y, 60, 26), brick);
      }
    }
    final cx = w * 0.4, cy = h * 0.41, R = min(w * 0.26, h * 0.29);
    // embrasure
    final frame = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy), width: R * 2.5, height: R * 2.35),
        Radius.circular(R * 0.2));
    c.drawRRect(frame.inflate(8), Paint()..color = const Color(0xFF050505));
    // intérieur : lingots (visibles quand la porte s'ouvre)
    c.drawRRect(frame, Paint()..color = const Color(0xFF16120A));
    final gold = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFFFFF2B0), Color(0xFFE0A82E), Color(0xFF8A5A10)])
          .createShader(
              Rect.fromCenter(center: Offset(cx, cy), width: R * 2, height: R));
    for (var row = 0; row < 3; row++) {
      for (var k = 0; k < 4 - row; k++) {
        final bx = cx - R * 0.8 + k * R * 0.42 + row * R * 0.21;
        final by = cy + R * 0.6 - row * R * 0.2;
        final p = Path()
          ..moveTo(bx, by)
          ..lineTo(bx + R * 0.38, by)
          ..lineTo(bx + R * 0.32, by - R * 0.16)
          ..lineTo(bx + R * 0.06, by - R * 0.16)
          ..close();
        c.drawPath(p, gold);
      }
    }
    // porte : pivote sur sa gauche (perspective)
    final swing = open <= 0
        ? 0.0
        : open < 0.75
            ? Curves.easeInOut.transform(open / 0.75)
            : 1 - Curves.easeIn.transform((open - 0.75) / 0.25);
    c.save();
    final hinge = Offset(frame.left, cy);
    c.translate(hinge.dx, hinge.dy);
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(-swing * 1.25);
    c.transform(m.storage);
    c.translate(-hinge.dx, -hinge.dy);
    final door = frame.deflate(6);
    c.drawRRect(
        door,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9DA2AA), Color(0xFF5B6068), Color(0xFF373B42)],
          ).createShader(door.outerRect));
    // rivets
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * 2 * pi;
      final p = Offset(cx + cos(a) * R * 1.08, cy + sin(a) * R * 1.0);
      c.drawCircle(p, 4, Paint()..color = const Color(0xFF2A2D33));
      c.drawCircle(p - const Offset(1, 1), 2, Paint()..color = Colors.white24);
    }
    // charnières
    for (final dy in [-0.7, 0.7]) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(door.left + 4, cy + dy * R),
                  width: 18,
                  height: R * 0.35),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFF2B2E34));
    }
    // molette
    c.drawCircle(
        Offset(cx, cy), R * 0.78, Paint()..color = const Color(0xFF1B1D21));
    c.save();
    c.translate(cx, cy);
    c.rotate(angle);
    for (var i = 0; i < 60; i++) {
      final big = i % 5 == 0;
      c.drawLine(
          Offset(R * (big ? 0.62 : 0.68), 0),
          Offset(R * 0.74, 0),
          Paint()
            ..color = Colors.white.withValues(alpha: big ? 0.9 : 0.5)
            ..strokeWidth = big ? 2.5 : 1.2);
      if (big) {
        paintText(
            c, '${i ~/ 5 * 5}', Offset(R * 0.53, 0), R * 0.07, Colors.white60);
      }
      c.rotate(2 * pi / 60);
    }
    // poignée en étoile
    for (var k = 0; k < 4; k++) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-R * 0.05, -R * 0.42, R * 0.1, R * 0.84),
              Radius.circular(R * 0.05)),
          Paint()..color = const Color(0xFF8C9199));
      c.rotate(pi / 4);
    }
    c.restore();
    c.drawCircle(
        Offset(cx, cy),
        R * 0.3,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFF2A2C30), Color(0xFF0E0F11)])
              .createShader(
                  Rect.fromCircle(center: Offset(cx, cy), radius: R * 0.3)));
    // code restant
    final lit = left > 0
        ? const Color(0xFF7CFF9E)
        : left == 0
            ? const Color(0xFFFFD34F)
            : Tv.red;
    paintText(
        c,
        left > 0
            ? '$left'
            : left == 0
                ? 'OK'
                : '!!',
        Offset(cx, cy - R * 0.03),
        R * 0.34,
        lit,
        weight: FontWeight.w900);
    c.restore();
    // repère au-dessus de la molette
    final tip = Offset(cx, cy - R * 0.84);
    c.drawPath(
        Path()
          ..moveTo(tip.dx - 8, tip.dy - 12)
          ..lineTo(tip.dx + 8, tip.dy - 12)
          ..lineTo(tip.dx, tip.dy),
        Paint()..color = const Color(0xFFFFD34F));
    // panneau à droite : code, fléchettes
    final px = w * 0.79, top = h * 0.08;
    final panel = RRect.fromRectAndRadius(
        Rect.fromLTWH(px - w * 0.15, top, w * 0.3, h * 0.66),
        const Radius.circular(12));
    c.drawRRect(panel, Paint()..color = Colors.black.withValues(alpha: 0.6));
    c.drawRRect(
        panel,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFFD34F).withValues(alpha: 0.6));
    paintText(c, 'COFFRE $round / $rounds', Offset(px, top + h * 0.06), 15,
        Colors.white60);
    paintText(c, 'CODE', Offset(px, top + h * 0.13), 13, Colors.white54);
    paintText(c, '$code', Offset(px, top + h * 0.23), min(44, h * 0.13),
        const Color(0xFFFFD34F),
        weight: FontWeight.w900);
    final ph = h * 0.66;
    final slotTop = top + ph * 0.5, slotStep = ph * 0.16;
    for (var i = 0; i < 3; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(px, slotTop + i * slotStep),
              width: w * 0.24,
              height: slotStep * 0.8),
          const Radius.circular(8));
      final has = i < darts.length;
      c.drawRRect(
          r,
          Paint()
            ..color = has ? color.withValues(alpha: 0.35) : Colors.white10);
      paintText(c, has ? darts[i] : '·', r.center, min(18, slotStep * 0.5),
          has ? Colors.white : Colors.white30,
          weight: FontWeight.w900);
    }
    // lingots qui tombent à l'ouverture
    if (open > 0.15 && open < 1) {
      final r = Random(4);
      for (var i = 0; i < 18; i++) {
        final x = cx + (r.nextDouble() - 0.5) * R * 2.4;
        final y = -20 + ((open - 0.15) * 1.4 + r.nextDouble() * 0.4) * h;
        c.save();
        c.translate(x, y);
        c.rotate(r.nextDouble() * 2);
        c.drawRect(const Rect.fromLTWH(-12, -6, 24, 12), gold);
        c.restore();
      }
    }
    // gyrophare de l'alarme
    if (alarm > 0) {
      final a = (1 - alarm);
      final beam = (alarm * 6) % 1;
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..color = Tv.red
                .withValues(alpha: 0.22 * a * (0.5 + 0.5 * sin(alarm * 40))));
      final o = Offset(w * 0.5, 0);
      c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + cos(beam * 2 * pi) * w, o.dy + h)
            ..lineTo(o.dx + cos(beam * 2 * pi + 0.3) * w, o.dy + h)
            ..close(),
          Paint()..color = Tv.red.withValues(alpha: 0.25 * a));
    }
    // vignette
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55)
          ], stops: const [
            0.6,
            1
          ]).createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(_VaultPainter o) => true;
}
