// 8 Ball Pool : table néon synthwave ; les billes de chaque joueur
// (pleines / rayées) le long de leur bande, la 8 au centre ; la bille
// empochée file vers une poche puis rejoint la gouttière du joueur.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import 'common.dart';

class PoolScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const PoolScene({super.key, required this.game, required this.colorOf});
  @override
  State<PoolScene> createState() => _PoolSceneState();
}

class _PoolSceneState extends State<PoolScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _pot = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 850));
  late final AnimationController _win = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
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
        final streak = game.currentTurn.okCount;
        if (streak >= 2) {
          _pops.currentState?.add(Pop('SÉRIE ×$streak', const Color(0xFFFFD36A),
              const Offset(0.45, 0.5),
              size: 38));
        }
      case 'eight':
        _ball = 8;
        _pot.forward(from: 0);
        _win.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pot.dispose();
    _win.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final balls = poolBalls(g);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pot, _win, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _PoolPainter(
                balls: balls,
                colors: [
                  for (var i = 0; i < g.players.length; i++) widget.colorOf(i)
                ],
                names: [for (final p in g.players) p.name.toUpperCase()],
                current: g.finished ? -1 : g.current,
                eightOn: balls.isNotEmpty &&
                    !g.finished &&
                    balls[g.current].every((b) => b.$2),
                potting: _pot.isAnimating ? _ball : null,
                pot: _pot.value,
                win: _win.isAnimating ? _win.value : 0,
                eightGone: g.finished &&
                    g.winners.isNotEmpty &&
                    g.stateOf(g.winners.first).done,
                t: ambient.value,
              ),
            ),
          ),
        ),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _PoolPainter extends CustomPainter {
  final List<List<(int, bool, bool)>> balls;
  final List<Color> colors;
  final List<String> names;
  final int current;
  final bool eightOn, eightGone;
  final int? potting;
  final double pot, win, t;
  _PoolPainter(
      {required this.balls,
      required this.colors,
      required this.names,
      required this.current,
      required this.eightOn,
      required this.potting,
      required this.pot,
      required this.win,
      required this.eightGone,
      required this.t});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0630), Color(0xFF07020E)],
          ).createShader(Offset.zero & s));
    final table = Rect.fromLTRB(16, 14, w - 16, h - 14);
    final felt = table.deflate(14);
    // cadre néon
    final neon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFFFF4FD8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
    c.drawRRect(RRect.fromRectAndRadius(table, const Radius.circular(18)),
        Paint()..color = const Color(0xFF16062E));
    c.drawRRect(
        RRect.fromRectAndRadius(table, const Radius.circular(18)), neon);
    c.drawRRect(
        RRect.fromRectAndRadius(felt, const Radius.circular(10)),
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFF2A0F66), Color(0xFF12063A)])
              .createShader(felt));
    // grille synthwave sur le tapis
    final grid = Paint()
      ..color = const Color(0xFF2DE2FF).withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var x = felt.left; x < felt.right; x += felt.width / 14) {
      c.drawLine(Offset(x, felt.top), Offset(x, felt.bottom), grid);
    }
    for (var y = felt.top; y < felt.bottom; y += felt.height / 7) {
      c.drawLine(Offset(felt.left, y), Offset(felt.right, y), grid);
    }
    // poches
    final pockets = [
      felt.topLeft,
      felt.topCenter,
      felt.topRight,
      felt.bottomLeft,
      felt.bottomCenter,
      felt.bottomRight,
    ];
    for (final p in pockets) {
      c.drawCircle(p, 13, Paint()..color = Colors.black);
      c.drawCircle(
          p,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF2DE2FF).withValues(alpha: 0.6));
    }
    final r = min(felt.height * 0.075, felt.width * 0.036);
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 5);
    // billes de chaque joueur : rangée du haut (J1), du bas (J2)
    for (var p = 0; p < balls.length && p < 2; p++) {
      final y = p == 0
          ? felt.top + felt.height * 0.24
          : felt.bottom - felt.height * 0.24;
      final x0 = felt.left + felt.width * 0.12;
      final step = felt.width * 0.088;
      paintText(
          c,
          names[p],
          Offset(felt.left + 6, p == 0 ? felt.top + 10 : felt.bottom - 10),
          12,
          colors[p],
          align: TextAlign.left,
          weight: FontWeight.w900);
      for (var i = 0; i < balls[p].length; i++) {
        final (n, potted, strong) = balls[p][i];
        var o = Offset(x0 + i * step, y);
        var a = 1.0;
        if (potted && potting != n) {
          // dans la gouttière, à droite, en petit
          final gx = felt.right - felt.width * 0.18 + (i % 4) * r * 1.3;
          final gy = y + (i ~/ 4) * r * 1.3 * (p == 0 ? 1 : -1);
          paintBall(c, Offset(gx, gy), r * 0.6, colors[p],
              label: '$n', stripe: p == 1, alpha: 0.55);
          continue;
        }
        if (potting == n) {
          final pk = pockets
              .reduce((a, b) => (a - o).distance < (b - o).distance ? a : b);
          o = Offset.lerp(o, pk, Curves.easeIn.transform(pot))!;
          a = 1 - pot;
        }
        if (p == current && !potted) {
          c.drawCircle(
              o,
              r * 1.45,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = colors[p].withValues(alpha: 0.3 + 0.6 * pulse));
        }
        paintBall(c, o, r, colors[p],
            label: '$n', stripe: p == 1, alpha: a.clamp(0.0, 1.0));
        if (strong) {
          paintText(c, 'D/T', o + Offset(0, r * 1.45), r * 0.55, Colors.white70,
              weight: FontWeight.w900);
        }
      }
    }
    // la 8
    if (!eightGone || potting == 8) {
      var o = felt.center;
      var a = 1.0;
      if (potting == 8) {
        o = Offset.lerp(o, felt.topCenter, Curves.easeIn.transform(pot))!;
        a = 1 - pot;
      }
      if (eightOn) {
        c.drawCircle(
            o,
            r * 2,
            Paint()
              ..color =
                  const Color(0xFFFFD36A).withValues(alpha: 0.35 + 0.4 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      }
      paintBall(c, o, r * 1.25, const Color(0xFF111111),
          label: '8', alpha: a.clamp(0.0, 1.0));
      paintText(c, 'BULL', o + Offset(0, r * 2.1), r * 0.7, Colors.white60,
          weight: FontWeight.w900);
    }
    // feu d'artifice de la victoire
    if (win > 0) {
      for (var k = 0; k < 4; k++) {
        final f = (win * 1.4 - k * 0.15).clamp(0.0, 1.0);
        Burst(
                Offset(0.2 + k * 0.2, 0.3 + (k % 2) * 0.25),
                [
                  const Color(0xFFFF4FD8),
                  const Color(0xFF2DE2FF),
                  const Color(0xFFFFD36A),
                  Colors.white
                ][k],
                count: 26,
                speed: 0.9,
                seed: k * 31)
            .paint(c, s, f);
      }
    }
  }

  @override
  bool shouldRepaint(_PoolPainter o) => true;
}
