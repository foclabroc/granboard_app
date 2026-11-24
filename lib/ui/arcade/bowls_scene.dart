// Boules (lawn bowls) : gazon tondu en bandes vu de dessus, cochonnet
// au centre ; chaque boule roule jusqu'à sa place (anneau touché, du côté
// du numéro). Fin de mène : les boules qui marquent brillent.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class BowlsScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const BowlsScene({super.key, required this.game, required this.colorOf});
  @override
  State<BowlsScene> createState() => _BowlsSceneState();
}

class _BowlsSceneState extends State<BowlsScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _roll = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _end = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  (int, int)? _rolling; // joueur, boule
  int _endWinner = -1;
  int? _endIndex;

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    if (e['type'] == 'ball') {
      _rolling = (e['p'] as int, e['k'] as int);
      _roll.forward(from: 0);
    } else if (e['type'] == 'end') {
      _endWinner = e['w'] as int;
      _endIndex = e['e'] as int?;
      _end.forward(from: 0);
      final w = _endWinner;
      _pops.currentState?.add(w < 0
          ? Pop('MÈNE NULLE', Colors.white, const Offset(0.5, 0.2))
          : Pop('+${e['shots']} ${game.players[w].name.toUpperCase()}',
              widget.colorOf(w), const Offset(0.5, 0.2),
              size: 40));
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _end.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    // juste après la fin de mène, ses boules restent affichées le temps
    // de voir qui a marqué
    final showEnd = _end.isAnimating && _endIndex != null && !_roll.isAnimating;
    final balls = bowlsBalls(g, end: showEnd ? _endIndex : null);
    final ends = (g.shared['ends'] as List?) ?? const [];
    final total = g.settings.goalOrDefault;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_roll, _end, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _LawnPainter(
                balls: balls,
                colors: [
                  for (var i = 0; i < g.players.length; i++) widget.colorOf(i)
                ],
                rolling: _roll.isAnimating ? _rolling : null,
                roll: _roll.value,
                endWinner: _end.isAnimating ? _endWinner : -2,
                end: _end.value,
                t: ambient.value,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('MÈNES ', style: Tv.label(12, color: Colors.white70)),
              for (var i = 0; i < total; i++)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < ends.length && (ends[i] as List)[0] >= 0
                        ? widget.colorOf((ends[i] as List)[0] as int)
                        : Colors.black38,
                    border: Border.all(color: Colors.white54),
                  ),
                  alignment: Alignment.center,
                  child: i < ends.length && (ends[i] as List)[1] > 0
                      ? Text('${(ends[i] as List)[1]}',
                          style: Tv.title(10, color: Colors.black))
                      : null,
                ),
            ],
          ),
        ),
        Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: ScoreStrip(game: g, colorOf: widget.colorOf)),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _LawnPainter extends CustomPainter {
  final List<(int, int, int, int)> balls;
  final List<Color> colors;
  final (int, int)? rolling;
  final double roll, end, t;
  final int endWinner;
  _LawnPainter(
      {required this.balls,
      required this.colors,
      required this.rolling,
      required this.roll,
      required this.endWinner,
      required this.end,
      required this.t});

  static const _order = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5
  ];
  static const _radius = [0.07, 0.17, 0.33, 0.5, 0.67, 0.85, 1.05];

  Offset place(Offset c, double R, int p, int k, int d, int n) {
    final idx = _order.indexOf(n);
    final a = idx < 0
        ? (p * 2.1 + k * 1.3)
        : idx / 20 * 2 * pi - pi / 2 + (k - 1) * 0.11 + p * 0.05;
    final jitter = (((p * 7 + k * 13) % 5) - 2) * 0.012;
    return c + Offset(cos(a), sin(a)) * R * (_radius[d] + jitter);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // bandes de tonte
    for (var i = 0; i < 12; i++) {
      canvas.drawRect(
          Rect.fromLTWH(i * w / 12, 0, w / 12 + 1, h),
          Paint()
            ..color =
                i.isEven ? const Color(0xFF3F8F3A) : const Color(0xFF357F31));
    }
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.35)
            ],
          ).createShader(Offset.zero & s));
    final c = Offset(w / 2, h * 0.47);
    final R = min(w * 0.45, h * 0.36);
    // anneaux de distance discrets
    const names = ['', '25', 'S.INT', 'TRIPLE', 'S.EXT', 'DOUBLE'];
    for (var i = 1; i < 6; i++) {
      final r = R * (_radius[i] + _radius[i - 1]) / 2 + R * 0.02;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.16));
      final la = pi / 4 + (i - 3) * 0.16;
      paintText(canvas, names[i], c + Offset(cos(la), sin(la)) * r, 9,
          Colors.white.withValues(alpha: 0.4));
    }
    // cochonnet
    paintBall(canvas, c, R * 0.06, const Color(0xFFF7F3E4));
    // boules
    for (final (p, k, d, n) in balls) {
      var o = place(c, R, p, k, d, n);
      var r = R * 0.095;
      final isRolling = rolling == (p, k);
      if (isRolling) {
        final start = Offset(w / 2 + (p.isEven ? -1 : 1) * w * 0.18, h + r * 2);
        final u = Curves.easeOutCubic.transform(roll);
        final ctrl = Offset((start.dx + o.dx) / 2 + (p.isEven ? -60 : 60),
            (start.dy + o.dy) / 2);
        o = Offset(
          (1 - u) * (1 - u) * start.dx +
              2 * (1 - u) * u * ctrl.dx +
              u * u * o.dx,
          (1 - u) * (1 - u) * start.dy +
              2 * (1 - u) * u * ctrl.dy +
              u * u * o.dy,
        );
      }
      final scoring = endWinner == p;
      if (scoring) {
        final pulse = 0.5 + 0.5 * sin(end * 2 * pi * 5);
        canvas.drawCircle(
            o,
            r * (1.6 + pulse * 0.4),
            Paint()
              ..color = colors[p].withValues(alpha: 0.5 * (1 - end))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
      if (d >= 6) r *= 0.9; // dans le fossé
      paintBall(canvas, o, r, colors[p]);
      canvas.drawCircle(
          o,
          r * 0.55,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..color = Colors.white.withValues(alpha: 0.7));
    }
    // vignette
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
              stops: const [0.65, 1]).createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(_LawnPainter o) => true;
}
