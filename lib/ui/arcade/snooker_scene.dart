// Snooker : table en bois et drap vert, 15 rouges en triangle (leur
// numéro dessus), couleurs sur leurs mouches ; la bille empochée file
// vers la poche ; faute = éclair rouge.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

const _ballColors = {
  16: Color(0xFFF2D22E),
  17: Color(0xFF1E8A3A),
  18: Color(0xFF7A4A1A),
  19: Color(0xFF2050D0),
  20: Color(0xFFFF7AB0),
  25: Color(0xFF151515),
};

class SnookerScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const SnookerScene({super.key, required this.game, required this.colorOf});
  @override
  State<SnookerScene> createState() => _SnookerSceneState();
}

class _SnookerSceneState extends State<SnookerScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _pot = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _foul = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  int? _ball;

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'pot':
        _ball = e['ball'] as int;
        _pot.forward(from: 0);
        _pops.currentState?.add(Pop('+${e['v']}', widget.colorOf(e['p'] as int),
            const Offset(0.5, 0.2)));
      case 'foul':
        _foul.forward(from: 0);
        _pops.currentState?.add(Pop(
            'FAUTE +${e['pen']}', Tv.red, const Offset(0.5, 0.45),
            size: 42));
    }
  }

  @override
  void dispose() {
    _pot.dispose();
    _foul.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final (reds, want, next) = snookerState(g);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pot, _foul, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _TablePainter(
                reds: reds,
                want: want,
                next: next,
                potting: _pot.isAnimating ? _ball : null,
                pot: _pot.value,
                foul: _foul.isAnimating ? _foul.value : 0,
                t: ambient.value,
                finished: g.finished,
              ),
            ),
          ),
        ),
        Positioned(
            left: 6,
            right: 6,
            top: 6,
            child: ScoreStrip(game: g, colorOf: widget.colorOf, sub: g.infoOf)),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _TablePainter extends CustomPainter {
  final List<int> reds;
  final String want;
  final int next;
  final int? potting;
  final double pot, foul, t;
  final bool finished;
  _TablePainter(
      {required this.reds,
      required this.want,
      required this.next,
      required this.potting,
      required this.pot,
      required this.foul,
      required this.t,
      required this.finished});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0B0805));
    final outer = Rect.fromLTRB(8, 48, w - 8, h - 8);
    final cloth = outer.deflate(min(outer.height * 0.09, 22));
    // bois
    c.drawRRect(
        RRect.fromRectAndRadius(outer, const Radius.circular(16)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7A4A22), Color(0xFF4A2A12), Color(0xFF6A3E1C)],
          ).createShader(outer));
    // drap
    c.drawRect(
        cloth,
        Paint()
          ..shader = const RadialGradient(
            radius: 0.9,
            colors: [Color(0xFF23A050), Color(0xFF136B33)],
          ).createShader(cloth));
    // bandes
    c.drawRect(
        cloth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF0E5A2A));
    // poches
    final pr = cloth.height * 0.075;
    final pockets = [
      cloth.topLeft,
      cloth.topCenter,
      cloth.topRight,
      cloth.bottomLeft,
      cloth.bottomCenter,
      cloth.bottomRight,
    ];
    for (final p in pockets) {
      c.drawCircle(p, pr * 1.15, Paint()..color = const Color(0xFF2A1A0C));
      c.drawCircle(p, pr, Paint()..color = Colors.black);
    }
    // ligne de baulk et D (à gauche)
    final bx = cloth.left + cloth.width * 0.2;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    c.drawLine(Offset(bx, cloth.top), Offset(bx, cloth.bottom), line);
    final dR = cloth.height * 0.17;
    c.drawArc(Rect.fromCircle(center: Offset(bx, cloth.center.dy), radius: dR),
        pi / 2, pi, false, line);
    final r = cloth.height * 0.055;
    // mouches des couleurs
    final spots = {
      16: Offset(bx, cloth.center.dy + dR),
      18: Offset(bx, cloth.center.dy),
      17: Offset(bx, cloth.center.dy - dR),
      19: cloth.center,
      20: Offset(cloth.left + cloth.width * 0.7, cloth.center.dy),
      25: Offset(cloth.left + cloth.width * 0.91, cloth.center.dy),
    };
    // triangle des rouges, derrière la rose
    final apex =
        Offset(cloth.left + cloth.width * 0.7 + r * 2.2, cloth.center.dy);
    final redPos = <int, Offset>{};
    var n = 1;
    for (var row = 0; row < 5; row++) {
      for (var k = 0; k <= row; k++) {
        redPos[n++] = apex + Offset(row * r * 1.75, (k - row / 2) * r * 2.02);
      }
    }
    final glow = 0.5 + 0.5 * sin(t * 2 * pi * 5);
    void target(Offset o) => c.drawCircle(
        o,
        r * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.35 + 0.5 * glow));
    // les rouges
    for (final e in redPos.entries) {
      final on = reds.contains(e.key);
      if (!on && potting != e.key) continue;
      var o = e.value;
      var a = 1.0;
      if (potting == e.key) {
        final pk = pockets
            .reduce((p, q) => (p - o).distance < (q - o).distance ? p : q);
        o = Offset.lerp(o, pk, Curves.easeIn.transform(pot))!;
        a = 1 - pot * 0.9;
      }
      if (!finished && want == 'red' && on) target(o);
      paintBall(c, o, r * (potting == e.key ? 1 - pot * 0.4 : 1),
          const Color(0xFFC4141C),
          label: '${e.key}', alpha: a);
    }
    // les couleurs (encore sur la table)
    for (final e in spots.entries) {
      final idx = kSnookerColors.indexOf(e.key);
      final gone = want == 'final' && idx < next && potting != e.key;
      if (gone) continue;
      var o = e.value;
      var a = 1.0;
      if (potting == e.key) {
        final pk = pockets
            .reduce((p, q) => (p - o).distance < (q - o).distance ? p : q);
        final f = pot < 0.6 ? pot / 0.6 : 1.0;
        o = Offset.lerp(o, pk, Curves.easeIn.transform(f))!;
        a = pot < 0.6 ? 1 : 0; // la couleur revient sur sa mouche (phase 1)
        if (pot >= 0.6 && want != 'final') {
          o = e.value;
          a = (pot - 0.6) / 0.4;
        }
      }
      final isTarget =
          !finished && (want == 'color' || (want == 'final' && idx == next));
      if (isTarget) target(o);
      paintBall(c, o, r, _ballColors[e.key]!,
          label: e.key == 25 ? 'B' : '${e.key}', alpha: a.clamp(0.0, 1.0));
    }
    // blanche
    paintBall(c, Offset(bx - dR * 0.5, cloth.center.dy + dR * 0.3), r,
        const Color(0xFFF7F4EA));
    // faute
    if (foul > 0) {
      c.drawRect(Offset.zero & s,
          Paint()..color = Tv.red.withValues(alpha: 0.35 * (1 - foul)));
    }
  }

  @override
  bool shouldRepaint(_TablePainter o) => true;
}
