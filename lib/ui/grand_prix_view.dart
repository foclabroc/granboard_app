// Grand Prix (jeu Party) : la course sur un circuit vu de dessus, une
// voiture par joueur. Écran partagé téléphone / TV : circuit | cible
// (ton numéro) + joueur en cours + boutons.

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/practice.dart';
import 'dartboard.dart';
import 'game_fx.dart';
import 'theme.dart';

class GrandPrixLayout extends StatelessWidget {
  final PracticeGame game;
  final GlobalKey<GameSplashState> splashKey;
  final Widget? actionBar;
  final Widget panel;
  final Color Function(int player) colorOf;

  /// Scène à la place du circuit (jeux arcade).
  final Widget? scene;
  const GrandPrixLayout(
      {super.key,
      required this.game,
      required this.splashKey,
      required this.panel,
      required this.colorOf,
      this.actionBar,
      this.scene});

  @override
  Widget build(BuildContext context) {
    final t = game.currentTurn;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 13,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
                child: scene ?? RaceTrack(game: game, colorOf: colorOf),
              ),
            ),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: LayoutBuilder(
                      builder: (context, c) => Center(
                        child: AnimatedDartboard(
                          key: const ValueKey('gp-board'),
                          skin: PlayerBoards.instance
                              .of(game.players[game.current].id),
                          size: min(c.maxWidth, c.maxHeight) - 8,
                          hits: [
                            for (final d in t.darts)
                              if (d.hit != null) d.hit!
                          ],
                          targets: game.finished ? const [] : game.targetZones,
                          win: game.finished,
                          dartColor: colorOf(game.current),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: LayoutBuilder(builder: (context, c) {
                      // Sur téléphone la colonne est basse : on dessine le
                      // panneau à sa taille normale puis on le réduit.
                      const minH = 230.0;
                      if (c.maxHeight >= minH) return panel;
                      final k = c.maxHeight / minH;
                      return FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                            width: c.maxWidth / k, height: minH, child: panel),
                      );
                    }),
                  ),
                  if (actionBar != null) actionBar!,
                ],
              ),
            ),
          ],
        ),
        Positioned.fill(
            child: IgnorePointer(child: GameSplash(key: splashKey))),
      ],
    );
  }
}

/// Le circuit : un couloir par voiture, cases numérotées, départ et
/// arrivée ; turbo (flammes, traînées) et tête-à-queue (tour sur
/// elle-même) d'après le dernier évènement de la partie.
class RaceTrack extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int player) colorOf;
  const RaceTrack({super.key, required this.game, required this.colorOf});

  @override
  State<RaceTrack> createState() => _RaceTrackState();
}

class _RaceTrackState extends State<RaceTrack> {
  /// Évènement déjà joué (rejeu sans effets au départ).
  int? _seen;
  int? _boost, _spin;
  int _boostKey = 0, _spinKey = 0;

  @override
  void initState() {
    super.initState();
    _seen = _event?['n'] as int?;
  }

  Map? get _event => widget.game.shared['gp'] as Map?;

  void _checkEvent() {
    final e = _event;
    final n = e?['n'] as int?;
    if (n == null || n == _seen) return;
    _seen = n;
    if (e!['boost'] case final int p) {
      _boost = p;
      _boostKey++;
    }
    if (e['spin'] case final int p) {
      _spin = p;
      _spinKey++;
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkEvent();
    final g = widget.game;
    final nums = grandPrixNumbers(g);
    final length = g.settings.goalOrDefault;
    final n = g.players.length;
    final pos = [for (var i = 0; i < n; i++) g.stateOf(i).score];
    final best = pos.reduce(max);
    final soloLead = best > 0 && pos.where((p) => p == best).length == 1;
    final rank = [
      for (var i = 0; i < n; i++) 1 + pos.where((p) => p > pos[i]).length
    ];
    return LayoutBuilder(builder: (context, c) {
      const head = 22.0; // numéros des cases au-dessus du circuit
      const curb = 8.0;
      final w = c.maxWidth, h = c.maxHeight - head;
      final laneH = (h - curb * 2) / n;
      final boxW = min(w * 0.2, 150.0);
      final carW = min(laneH * 2.3, w * 0.17);
      final carH = carW * 50 / 120;
      final x0 = boxW + carW * 0.98, x1 = w - max(10.0, w * 0.03);
      double xAt(int p) => x0 + (x1 - x0) * min(p, length) / length;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TrackPainter(
                  n: n,
                  length: length,
                  head: head,
                  curb: curb,
                  boxW: boxW,
                  xAt: xAt,
                  current: g.finished ? -1 : g.current),
            ),
          ),
          for (var i = 0; i < n; i++)
            Positioned(
              key: ValueKey('gp-box-$i'),
              left: 0,
              top: head + curb + laneH * i,
              width: boxW,
              height: laneH,
              child: _LaneBox(
                number: nums.isEmpty ? 0 : nums[i],
                name: g.players[i].name,
                color: widget.colorOf(i),
                rank: rank[i],
                pos: pos[i],
                length: length,
                current: i == g.current && !g.finished,
              ),
            ),
          for (var i = 0; i < n; i++)
            AnimatedPositioned(
              key: ValueKey('gp-car-$i'),
              duration: const Duration(milliseconds: 950),
              curve: Curves.easeOutBack,
              left: xAt(pos[i]) - carW * 0.96,
              top: head + curb + laneH * i + (laneH - carH) / 2,
              width: carW,
              height: carH,
              child: _Car(
                color: widget.colorOf(i),
                number: nums.isEmpty ? 0 : nums[i],
                lead: soloLead && pos[i] == best,
                current: i == g.current && !g.finished,
                boostKey: _boost == i ? _boostKey : 0,
                spinKey: _spin == i ? _spinKey : 0,
              ),
            ),
        ],
      );
    });
  }
}

class _TrackPainter extends CustomPainter {
  final int n, length, current;
  final double head, curb, boxW;
  final double Function(int) xAt;
  _TrackPainter(
      {required this.n,
      required this.length,
      required this.head,
      required this.curb,
      required this.boxW,
      required this.xAt,
      required this.current});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, top = head, bottom = size.height;
    final road = Rect.fromLTRB(0, top, w, bottom);
    canvas.drawRect(road, Paint()..color = const Color(0xFF3A3D44));
    // grain du bitume
    final rnd = Random(7);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < 260; i++) {
      canvas.drawCircle(
          Offset(rnd.nextDouble() * w, top + rnd.nextDouble() * (bottom - top)),
          0.9,
          dot);
    }
    // vibreurs
    const cw = 22.0;
    for (final y in [top, bottom - curb]) {
      var k = 0;
      for (var x = 0.0; x < w; x += cw, k++) {
        canvas.drawRect(Rect.fromLTWH(x, y, cw, curb),
            Paint()..color = k.isEven ? const Color(0xFFE8242C) : const Color(0xFFF5F5F5));
      }
    }
    final laneH = (bottom - top - curb * 2) / n;
    // couloir du joueur en cours
    if (current >= 0) {
      canvas.drawRect(
          Rect.fromLTWH(0, top + curb + laneH * current, w, laneH),
          Paint()..color = Colors.white.withValues(alpha: 0.07));
    }
    // séparations des couloirs (pointillés)
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (var i = 1; i < n; i++) {
      final y = top + curb + laneH * i;
      for (var x = boxW; x < w; x += 28) {
        canvas.drawLine(Offset(x, y), Offset(x + 14, y), dash);
      }
    }
    // traits des cases + numéros au-dessus
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2;
    for (var i = 1; i < length; i++) {
      final x = xAt(i);
      canvas.drawLine(Offset(x, top + curb), Offset(x, bottom - curb), tick);
    }
    for (var i = 0; i <= length; i++) {
      final x = xAt(i);
      final label = i == 0 ? 'DÉPART' : '$i';
      final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  fontFamily: Tv.font,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: i == 0 ? Colors.white : Colors.black)),
          textDirection: TextDirection.ltr)
        ..layout();
      final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, head / 2 - 1),
              width: tp.width + 8,
              height: tp.height + 2),
          const Radius.circular(3));
      canvas.drawRRect(
          r,
          Paint()
            ..color = i == 0
                ? Colors.black
                : i == length
                    ? const Color(0xFFE8242C)
                    : Colors.white);
      if (i == 0) {
        canvas.drawRRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = Colors.white);
      }
      tp.paint(canvas, Offset(x - tp.width / 2, head / 2 - 1 - tp.height / 2));
    }
    // ligne de départ
    canvas.drawRect(
        Rect.fromLTWH(xAt(0) - 2, top + curb, 4, bottom - top - curb * 2),
        Paint()..color = Colors.white);
    // arrivée en damier
    const sq = 9.0;
    final fx = xAt(length);
    var row = 0;
    for (var y = top + curb; y < bottom - curb; y += sq, row++) {
      for (var k = 0; k < 2; k++) {
        canvas.drawRect(
            Rect.fromLTWH(fx - sq + k * sq, y, sq, min(sq, bottom - curb - y)),
            Paint()..color = (row + k).isEven ? Colors.white : Colors.black);
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.n != n ||
      old.length != length ||
      old.current != current ||
      old.boxW != boxW ||
      old.head != head;
}

class _LaneBox extends StatelessWidget {
  final int number, rank, pos, length;
  final String name;
  final Color color;
  final bool current;
  const _LaneBox(
      {required this.number,
      required this.name,
      required this.color,
      required this.rank,
      required this.pos,
      required this.length,
      required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.black.withValues(alpha: 0.85),
          Colors.black.withValues(alpha: 0.55),
        ]),
        border: const Border(right: BorderSide(color: Colors.white70, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Text('$number',
                style: Tv.title(18, color: Colors.black)
                    .copyWith(fontStyle: FontStyle.italic)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(name.toUpperCase(),
                      maxLines: 1,
                      style: Tv.title(16,
                          color: current ? Colors.white : Tv.text)),
                ),
                Text('P$rank · $pos/$length',
                    maxLines: 1, style: Tv.label(11, color: Tv.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une monoplace vue de dessus (nez à droite), numéro à l'arrière.
/// [boostKey] / [spinKey] qui changent = flammes + traînées / tête-à-queue.
class _Car extends StatefulWidget {
  final Color color;
  final int number;
  final bool lead, current;
  final int boostKey, spinKey;
  const _Car(
      {required this.color,
      required this.number,
      required this.lead,
      required this.current,
      required this.boostKey,
      required this.spinKey});

  @override
  State<_Car> createState() => _CarState();
}

class _CarState extends State<_Car> with TickerProviderStateMixin {
  late final AnimationController _boost = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(_Car old) {
    super.didUpdateWidget(old);
    if (widget.boostKey != 0 && widget.boostKey != old.boostKey) {
      _boost.forward(from: 0);
    }
    if (widget.spinKey != 0 && widget.spinKey != old.spinKey) {
      _spin.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _boost.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_boost, _spin]),
        builder: (context, _) {
          final b = _boost.isAnimating ? 1 - _boost.value : 0.0;
          final s = _spin.isAnimating ? Curves.easeOut.transform(_spin.value) : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.current)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 14)
                      ],
                    ),
                  ),
                ),
              Positioned.fill(
                child: Transform.rotate(
                  angle: -2 * pi * s,
                  child: CustomPaint(
                      painter: _CarPainter(widget.color, widget.number,
                          flame: b, smoke: _spin.isAnimating ? 1 - _spin.value : 0)),
                ),
              ),
              if (widget.lead)
                Positioned(
                  left: -30,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF2C84B),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('P1',
                          style: Tv.title(14, color: Colors.black)
                              .copyWith(fontStyle: FontStyle.italic)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final Color color;
  final int number;

  /// Turbo (1 → 0) : flammes et traînées ; tête-à-queue : fumée.
  final double flame, smoke;
  _CarPainter(this.color, this.number, {this.flame = 0, this.smoke = 0});

  Color _shade(double f) =>
      f < 0 ? Color.lerp(color, Colors.black, -f)! : Color.lerp(color, Colors.white, f)!;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    canvas.save();
    canvas.scale(k, k);
    final dark = _shade(-0.35), light = _shade(0.35);
    // traînées de vitesse
    if (flame > 0) {
      final sp = Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * flame)
        ..strokeWidth = 1.6;
      for (final (y, l) in [(10.0, 40.0), (20.0, 60.0), (30.0, 50.0), (40.0, 36.0)]) {
        canvas.drawLine(Offset(-l * (1.4 - flame), y), Offset(-4, y), sp);
      }
    }
    // ombre
    canvas.drawOval(Rect.fromCenter(center: const Offset(60, 29), width: 112, height: 34),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    // flammes d'échappement
    if (flame > 0) {
      final f = 0.7 + 0.3 * sin(flame * 40);
      canvas.drawPath(
          Path()
            ..moveTo(4, 25)
            ..lineTo(4 - 14 * f, 21)
            ..lineTo(4 - 24 * f, 25)
            ..lineTo(4 - 14 * f, 29)
            ..close(),
          Paint()..color = const Color(0xFFFFB02E).withValues(alpha: flame));
      canvas.drawPath(
          Path()
            ..moveTo(4, 25)
            ..lineTo(4 - 9 * f, 23)
            ..lineTo(4 - 14 * f, 25)
            ..lineTo(4 - 9 * f, 27)
            ..close(),
          Paint()..color = const Color(0xFFFFF6C2).withValues(alpha: flame));
    }
    // roues
    void wheel(double x, double y) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 17, 9), const Radius.circular(2.5));
      canvas.drawRRect(r, Paint()..color = const Color(0xFF141414));
      canvas.drawLine(Offset(x + 2, y + 4.5), Offset(x + 15, y + 4.5),
          Paint()
            ..color = const Color(0xFF444444)
            ..strokeWidth = 3);
    }

    wheel(12, 2);
    wheel(12, 39);
    wheel(80, 4);
    wheel(80, 37);
    // aileron arrière
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(4, 6, 9, 38), const Radius.circular(2)),
        Paint()..color = dark);
    canvas.drawRect(const Rect.fromLTWH(2, 8, 4, 34), Paint()..color = const Color(0xFF111111));
    // carrosserie
    final body = Path()
      ..moveTo(10, 18)
      ..cubicTo(10, 14, 18, 12, 30, 12)
      ..lineTo(58, 13)
      ..cubicTo(70, 13, 80, 17, 98, 21)
      ..lineTo(114, 23)
      ..cubicTo(117, 23.5, 117, 26.5, 114, 27)
      ..lineTo(98, 29)
      ..cubicTo(80, 33, 70, 37, 58, 37)
      ..lineTo(30, 38)
      ..cubicTo(18, 38, 10, 36, 10, 32)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
        Path()
          ..moveTo(30, 12)
          ..lineTo(58, 13)
          ..cubicTo(66, 13, 72, 15, 80, 17)
          ..lineTo(58, 19)
          ..lineTo(30, 19)
          ..close(),
        Paint()..color = light.withValues(alpha: 0.55));
    // pontons
    for (final sgn in [1.0, -1.0]) {
      final y = 25 - sgn * 12;
      canvas.drawPath(
          Path()
            ..moveTo(24, y)
            ..lineTo(42, y - sgn * 4)
            ..lineTo(52, y - sgn * 4)
            ..lineTo(54, y + sgn * 1)
            ..close(),
          Paint()..color = dark);
    }
    // aileron avant
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(104, 5, 7, 40), const Radius.circular(2)),
        Paint()..color = dark);
    canvas.drawRect(const Rect.fromLTWH(108, 7, 3, 36), Paint()..color = const Color(0xFF111111));
    // nez
    canvas.drawLine(const Offset(60, 25), const Offset(96, 25),
        Paint()
          ..color = dark
          ..strokeWidth = 2);
    // cockpit + casque
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 25), width: 20, height: 12),
        Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(const Offset(48, 25), 4.6, Paint()..color = light);
    canvas.drawRect(const Rect.fromLTWH(47, 22.5, 4, 5), Paint()..color = const Color(0xFF1D2B44));
    // numéro à l'arrière
    canvas.drawCircle(const Offset(26, 25), 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(26, 25),
        7.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF111111));
    final tp = TextPainter(
        text: TextSpan(
            text: '$number',
            style: const TextStyle(
                fontFamily: Tv.font,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                color: Color(0xFF111111))),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(26 - tp.width / 2, 25 - tp.height / 2));
    // fumée du tête-à-queue
    if (smoke > 0) {
      for (var i = 0; i < 6; i++) {
        canvas.drawCircle(
            Offset(30 + i * 12.0, 25 + sin(i * 2.0) * 10),
            8 + (1 - smoke) * 14,
            Paint()..color = const Color(0xFFDCDCE1).withValues(alpha: 0.6 * smoke));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarPainter old) =>
      old.color != color ||
      old.number != number ||
      old.flame != flame ||
      old.smoke != smoke;
}
