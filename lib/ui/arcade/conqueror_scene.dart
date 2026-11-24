// Conquérant : la cible devient une carte de 20 régions autour du hub ;
// couleurs des propriétaires, boucliers, bases ; régions à portée qui
// clignotent ; prise et vol avec éclat, bouclier cassé en éclats.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class ConquerorScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const ConquerorScene({super.key, required this.game, required this.colorOf});
  @override
  State<ConquerorScene> createState() => _ConquerorSceneState();
}

class _ConquerorSceneState extends State<ConquerorScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _fx = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  int? _num;
  String _kind = '';

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    _num = e['num'] as int?;
    _kind = e['type'] as String;
    _fx.forward(from: 0);
    final p = e['p'] as int? ?? 0;
    final label = switch (_kind) {
      'claim' => 'PRISE !',
      'steal' => 'VOLÉE !',
      'break' => 'BOUCLIER BRISÉ',
      'shield' => '+ BOUCLIER',
      _ => null,
    };
    if (label != null) {
      _pops.currentState?.add(Pop(
          label,
          _kind == 'break' ? Colors.white : widget.colorOf(p),
          const Offset(0.5, 0.12),
          size: 30));
    }
  }

  @override
  void dispose() {
    _fx.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final (own, sh, reach) = conquerorState(g);
    final bases = {
      for (var i = 0; i < g.players.length; i++)
        if (g.stateOf(i).v['base'] case final int b) b: i
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fx, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _MapPainter(
                own: own,
                shields: sh,
                reach: g.finished ? const [] : reach,
                bases: bases,
                colors: [
                  for (var i = 0; i < g.players.length; i++) widget.colorOf(i)
                ],
                current: g.finished ? null : widget.colorOf(g.current),
                fxNum: _fx.isAnimating ? _num : null,
                fxKind: _kind,
                fx: _fx.value,
                t: ambient.value,
              ),
            ),
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
          bottom: 6,
          width: 150,
          child: Column(
            children: [
              for (var i = 0; i < g.players.length; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget
                            .colorOf(i)
                            .withValues(alpha: i == g.current ? 0.65 : 0.3),
                        Colors.black54,
                      ]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: i == g.current && !g.finished
                              ? Colors.white
                              : Colors.transparent),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(g.players[i].name.toUpperCase(),
                              style: Tv.title(15, color: Colors.white)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(g.infoOf(i),
                              style: Tv.title(13, color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _MapPainter extends CustomPainter {
  final Map<int, int> own, shields, bases;
  final List<int> reach;
  final List<Color> colors;
  final Color? current;
  final int? fxNum;
  final String fxKind;
  final double fx, t;
  _MapPainter(
      {required this.own,
      required this.shields,
      required this.reach,
      required this.bases,
      required this.colors,
      required this.current,
      required this.fxNum,
      required this.fxKind,
      required this.fx,
      required this.t});

  static void shield(Canvas c, Offset o, double s, Color col) {
    final p = Path()
      ..moveTo(o.dx - s, o.dy - s * 0.9)
      ..lineTo(o.dx + s, o.dy - s * 0.9)
      ..lineTo(o.dx + s, o.dy)
      ..quadraticBezierTo(o.dx + s * 0.9, o.dy + s, o.dx, o.dy + s * 1.3)
      ..quadraticBezierTo(o.dx - s * 0.9, o.dy + s, o.dx - s, o.dy)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFFEDEDED));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Color.lerp(col, Colors.black, 0.5)!);
    c.drawLine(
        Offset(o.dx, o.dy - s * 0.8),
        Offset(o.dx, o.dy + s),
        Paint()
          ..color = col
          ..strokeWidth = s * 0.35);
  }

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFF221A10), Color(0xFF0A0805)])
              .createShader(Offset.zero & s));
    final cx = (s.width - 156) / 2, cy = s.height / 2;
    final R = min(cx - 8, cy - 8);
    final hub = R * 0.2;
    final o = Offset(cx, cy);
    // mer autour
    c.drawCircle(o, R + 6, Paint()..color = const Color(0xFF0E2433));
    for (var i = 0; i < 20; i++) {
      final n = kArcadeBoardOrder[i];
      final a0 = (i - 0.5) / 20 * 2 * pi - pi / 2, a1 = a0 + 2 * pi / 20;
      final path = Path()
        ..arcTo(Rect.fromCircle(center: o, radius: R), a0, a1 - a0, true)
        ..arcTo(Rect.fromCircle(center: o, radius: hub + 4), a1, a0 - a1, false)
        ..close();
      final who = own[n];
      final base = who == null ? const Color(0xFF3A3630) : colors[who];
      c.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.lerp(base, Colors.black, 0.45)!,
                base,
                Color.lerp(base, Colors.white, 0.15)!
              ],
              stops: const [0.2, 0.75, 1],
            ).createShader(Rect.fromCircle(center: o, radius: R)));
      // relief (hachures pour les terres neutres)
      if (who == null) {
        c.save();
        c.clipPath(path);
        final hatch = Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..strokeWidth = 2;
        for (var k = -20; k < 20; k++) {
          c.drawLine(Offset(cx + k * 12 - R, cy - R),
              Offset(cx + k * 12 + R, cy + R), hatch);
        }
        c.restore();
      }
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black.withValues(alpha: 0.6));
      // à portée : contour qui clignote
      if (current != null && reach.contains(n)) {
        final pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2 * pi * 6));
        c.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = current!.withValues(alpha: pulse));
      }
      // effet sur la région touchée
      if (fxNum == n) {
        final a = 1 - fx;
        c.drawPath(
            path,
            Paint()
              ..color = (fxKind == 'break' ? Colors.white : base)
                  .withValues(alpha: 0.7 * a)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * a + 1));
        if (fxKind == 'break' || fxKind == 'steal') {
          final mid = (a0 + a1) / 2;
          Burst(
                  Offset((cx + cos(mid) * R * 0.75) / s.width,
                      (cy + sin(mid) * R * 0.75) / s.height),
                  Colors.white,
                  seed: n * 7,
                  count: 16,
                  speed: 0.6)
              .paint(c, s, fx);
        }
      }
      // numéro, boucliers, base
      final mid = (a0 + a1) / 2;
      final lab = o + Offset(cos(mid), sin(mid)) * R * 0.9;
      paintText(c, '$n', lab, R * 0.085, Colors.white,
          weight: FontWeight.w900, shadow: true);
      final k = shields[n] ?? 0;
      for (var j = 0; j < k; j++) {
        final p = o + Offset(cos(mid), sin(mid)) * R * (0.72 - j * 0.13);
        shield(c, p, R * 0.03, who == null ? Colors.grey : colors[who]);
      }
      if (bases.containsKey(n)) {
        final p = o + Offset(cos(mid), sin(mid)) * R * 0.36;
        _castle(c, p, R * 0.045, colors[bases[n]!]);
      }
    }
    // hub
    final hw = own[25];
    c.drawCircle(o, hub,
        Paint()..color = hw == null ? const Color(0xFF5A4A20) : colors[hw]);
    c.drawCircle(
        o,
        hub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFD34F)
              .withValues(alpha: 0.6 + 0.4 * sin(t * 2 * pi * 3)));
    _crown(c, o - Offset(0, hub * 0.25), hub * 0.32);
    paintText(c, 'HUB', o + Offset(0, hub * 0.42), hub * 0.32, Colors.white,
        weight: FontWeight.w900);
    for (var j = 0; j < (shields[25] ?? 0); j++) {
      shield(c, o + Offset((j - 1) * hub * 0.5, hub * 0.95), R * 0.025,
          hw == null ? Colors.grey : colors[hw]);
    }
    if (current != null && reach.contains(25)) {
      c.drawCircle(
          o,
          hub + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color =
                current!.withValues(alpha: 0.5 + 0.5 * sin(t * 2 * pi * 6)));
    }
  }

  void _crown(Canvas c, Offset o, double s) {
    final p = Path()
      ..moveTo(o.dx - s, o.dy + s * 0.6)
      ..lineTo(o.dx - s, o.dy - s * 0.4)
      ..lineTo(o.dx - s * 0.5, o.dy + s * 0.1)
      ..lineTo(o.dx, o.dy - s * 0.7)
      ..lineTo(o.dx + s * 0.5, o.dy + s * 0.1)
      ..lineTo(o.dx + s, o.dy - s * 0.4)
      ..lineTo(o.dx + s, o.dy + s * 0.6)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFFFFD34F));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF7A5A10));
  }

  void _castle(Canvas c, Offset o, double s, Color col) {
    final body = Rect.fromCenter(center: o, width: s * 2.4, height: s * 1.8);
    c.drawRect(body, Paint()..color = const Color(0xFFE8E2D0));
    for (var k = 0; k < 3; k++) {
      c.drawRect(
          Rect.fromLTWH(
              body.left + k * s * 0.9, body.top - s * 0.5, s * 0.6, s * 0.5),
          Paint()..color = const Color(0xFFE8E2D0));
    }
    c.drawRect(
        Rect.fromCenter(
            center: o + Offset(0, s * 0.4), width: s * 0.7, height: s),
        Paint()..color = col);
  }

  @override
  bool shouldRepaint(_MapPainter o) => true;
}
