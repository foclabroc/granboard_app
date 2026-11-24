// Zombies : cimetière la nuit (lune, brume, tombes), 6 couloirs ; les
// zombies avancent en titubant vers la base, leur cible sur une pancarte ;
// abattu = giclée verte, morsure = la base tremble et rougit.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class ZombiesScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const ZombiesScene({super.key, required this.game, required this.colorOf});
  @override
  State<ZombiesScene> createState() => _ZombiesSceneState();
}

class _ZombiesSceneState extends State<ZombiesScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _kill = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _bite = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  Map<int, Zombie> _last = {};
  Offset? _splat;

  @override
  void initState() {
    super.initState();
    _last = {for (final z in zombiesState(game).$1) z.id: z};
    startAmbient();
  }

  /// Décalage dans le couloir (plusieurs zombies dans le même couloir :
  /// un à gauche, un à droite) ; posé à chaque construction.
  Map<int, double> _shift = {};

  Offset _frac(Zombie z, [Map<int, double>? shift]) => Offset(
      (z.lane + 0.5 + ((shift ?? _shift)[z.id] ?? 0)) / kZombieLanes,
      0.2 + z.y / kZombieReach * 0.6);

  /// Perspective : plus petit au loin, taille pleine près de la base.
  static double _scale(Zombie z) =>
      0.72 + 0.28 * (z.y / (kZombieReach - 1)).clamp(0.0, 1.0);

  static Map<int, double> _shifts(List<Zombie> horde) {
    final out = <int, double>{};
    for (var lane = 0; lane < kZombieLanes; lane++) {
      final here = [
        for (final z in horde)
          if (z.lane == lane) z
      ]..sort((a, b) => a.y.compareTo(b.y));
      if (here.length < 2) continue;
      for (var i = 0; i < here.length; i++) {
        out[here[i].id] = i.isEven ? -0.17 : 0.17;
      }
    }
    return out;
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'kill':
        final z = _last[e['id']];
        if (z != null) {
          _splat = _frac(z);
          _kill.forward(from: 0);
          final p = e['p'] as int;
          _pops.currentState?.add(Pop(
              'ABATTU !', widget.colorOf(p), _splat! - const Offset(0, 0.05),
              size: 30));
        }
      case 'bite':
        _bite.forward(from: 0);
        _pops.currentState
            ?.add(Pop('MORSURE !', Tv.red, const Offset(0.5, 0.78), size: 40));
    }
  }

  @override
  void dispose() {
    _kill.dispose();
    _bite.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final (horde, hp) = zombiesState(g);
    // les zombies vus avant (pour la giclée de celui qui vient de tomber)
    final shift = _shifts(horde);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _last = {for (final z in horde) z.id: z};
      _shift = shift;
    });
    final wave = g.round;
    final waves = g.settings.goalOrDefault;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, c) {
        final zw = c.maxWidth / kZombieLanes * 0.8;
        final zh = c.maxHeight * 0.3;
        return AnimatedBuilder(
          animation: _bite,
          builder: (context, child) => Transform.translate(
              offset:
                  _bite.isAnimating ? shake(_bite.value, amp: 7) : Offset.zero,
              child: child),
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([ambient, _kill, _bite]),
                builder: (context, _) => CustomPaint(
                  painter: _NightPainter(
                    t: ambient.value,
                    hp: hp,
                    bite: _bite.isAnimating ? _bite.value : 0,
                  ),
                ),
              ),
            ),
            // du plus loin au plus près : le plus proche passe devant
            for (final z in [...horde]..sort((a, b) => a.y.compareTo(b.y)))
              AnimatedPositioned(
                key: ValueKey('z${z.id}'),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                left: _frac(z, shift).dx * c.maxWidth - zw * _scale(z) / 2,
                top: _frac(z, shift).dy * c.maxHeight - zh * _scale(z) * 0.55,
                width: zw * _scale(z),
                height: zh * _scale(z),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, appear, child) =>
                      Opacity(opacity: appear, child: child),
                  child: _ZombieView(
                      zombie: z,
                      ambient: ambient,
                      danger: z.y >= kZombieReach - 1),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _kill,
                  builder: (context, _) => CustomPaint(
                    painter: _SplatPainter(
                        _splat, _kill.isAnimating ? _kill.value : 0),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              child: Text('VAGUE ${min(wave, waves)} / $waves',
                  style: Tv.title(18, color: const Color(0xFFB4FF6A))),
            ),
            Positioned(
              top: 8,
              right: 10,
              child: Text(plural(horde.length, 'ZOMBIE', 'ZOMBIES'),
                  style: Tv.title(18, color: Colors.white70)),
            ),
            Positioned.fill(child: PopLayer(key: _pops)),
          ]),
        );
      }),
    );
  }
}

String plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

class _ZombieView extends StatelessWidget {
  final Zombie zombie;
  final Animation<double> ambient;
  final bool danger;
  const _ZombieView(
      {required this.zombie, required this.ambient, required this.danger});

  @override
  Widget build(BuildContext context) {
    final z = zombie;
    final plate = switch (z.m) {
      3 => const Color(0xFFFF5A4A),
      2 => const Color(0xFFFFB02E),
      _ => const Color(0xFFB4FF6A),
    };
    return AnimatedBuilder(
      animation: ambient,
      builder: (context, _) {
        final ph = ambient.value * 2 * pi * 10 + z.id * 1.7;
        return Transform.translate(
          offset: Offset(sin(ph) * 2.5, (sin(ph * 2)).abs() * -3),
          child: Transform.rotate(
            angle: sin(ph) * 0.06,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: danger ? Tv.red : plate, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: plate.withValues(alpha: 0.5), blurRadius: 8)
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(z.label, style: Tv.title(18, color: plate)),
                ),
              ),
              Expanded(
                  child: CustomPaint(
                      painter: _ZombiePainter(ph, zombieForm(z.id), danger),
                      child: const SizedBox.expand())),
            ]),
          ),
        );
      },
    );
  }
}

/// 5 formes, mélangées d'après l'id du zombie (choix de foclabroc sur la
/// maquette `zombies_formes.html`) : clochard, squelette, momie, toxique,
/// chibi. Dessinées les pieds en bas de la boîte, unité `u` ≈ 1/1,85 de la
/// hauteur.
enum ZombieForm { tramp, skeleton, mummy, toxic, chibi }

ZombieForm zombieForm(int id) =>
    ZombieForm.values[(id * 7 + 3) % ZombieForm.values.length];

class _ZombiePainter extends CustomPainter {
  final double ph;
  final ZombieForm form;
  final bool danger;
  _ZombiePainter(this.ph, this.form, this.danger);

  Color get _skin => danger ? const Color(0xFFB9C46A) : const Color(0xFF7FB069);

  static void _limb(Canvas c, List<Offset> pts, double w, Color col) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  /// Bras qui pendent le long du corps et se balancent (en opposition) :
  /// épaule à ±[spread], main à ±[handX] et à la hauteur [handY].
  static void _arms(Canvas c, double x, double shoulderY, double spread,
      double handX, double handY, double w, Color col, double t, double speed) {
    final len = handY - shoulderY;
    for (final side in [-1.0, 1.0]) {
      final sw = sin(t * speed + (side > 0 ? pi : 0)) * len * 0.22;
      final elbow = Offset(
          x + side * (spread + (handX - spread) * 0.6) + sw * .4,
          shoulderY + len * 0.5);
      _limb(
          c,
          [
            Offset(x + side * spread, shoulderY),
            elbow,
            Offset(x + side * handX + sw, handY),
          ],
          w,
          col);
    }
  }

  static void _eyes(Canvas c, Offset o, double r, double gap, Color col) {
    final p = Paint()
      ..color = col
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, r * 1.5);
    c.drawCircle(o + Offset(-gap, 0), r, p);
    if (gap > 0) c.drawCircle(o + Offset(gap, 0), r, p);
  }

  static void _shadow(Canvas c, Offset o, double w) => c.drawOval(
      Rect.fromCenter(center: o, width: w * 2, height: w * 0.44),
      Paint()..color = Colors.black.withValues(alpha: 0.4));

  @override
  void paint(Canvas c, Size s) {
    final u = min(s.height * 0.96 / 1.9, s.width / 1.7);
    final x = s.width / 2, y = s.height * 0.96;
    final t = ph / 3;
    switch (form) {
      case ZombieForm.tramp:
        _tramp(c, x, y, u, t);
      case ZombieForm.skeleton:
        _skeleton(c, x, y, u, t);
      case ZombieForm.mummy:
        _mummy(c, x, y, u, t);
      case ZombieForm.toxic:
        _toxic(c, x, y, u, t);
      case ZombieForm.chibi:
        _chibi(c, x, y, u, t);
    }
  }

  void _tramp(Canvas c, double x, double y, double u, double t) {
    final sw = sin(t * 3) * u * .08, tilt = sin(t * 1.5) * .15 + .25;
    _shadow(c, Offset(x, y), u * .55);
    const pants = Color(0xFF2C3F5C);
    _limb(
        c,
        [
          Offset(x - u * .12, y - u * .6),
          Offset(x - u * .2 + sw, y - u * .3),
          Offset(x - u * .12 + sw, y)
        ],
        u * .15,
        pants);
    _limb(
        c,
        [
          Offset(x + u * .12, y - u * .6),
          Offset(x + u * .22 - sw, y - u * .3),
          Offset(x + u * .18 - sw, y)
        ],
        u * .15,
        pants);
    final coat = Path()
      ..moveTo(x - u * .34, y - u * 1.15)
      ..lineTo(x + u * .34, y - u * 1.15)
      ..lineTo(x + u * .38, y - u * .55);
    for (var i = 0; i < 6; i++) {
      coat.lineTo(x + u * .38 - i * u * .152, y - u * (i.isOdd ? .48 : .58));
    }
    coat.close();
    c.drawPath(coat, Paint()..color = const Color(0xFF6B4A2F));
    c.drawCircle(Offset(x + u * .1, y - u * .85), u * .07,
        Paint()..color = const Color(0xFF5B8A4A));
    _arms(
        c, x, y - u * 1.05, u * .3, u * .4, y - u * .42, u * .12, _skin, t, 3);
    c.save();
    c.translate(x, y - u * 1.35);
    c.rotate(tilt);
    c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: u * .6, height: u * .68),
        Paint()..color = _skin);
    c.drawArc(
        Rect.fromCircle(center: Offset(-u * .08, -u * .3), radius: u * .18),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFF2A1A10));
    _eyes(c, Offset(0, -u * .02), u * .06, u * .12, const Color(0xFFFFD23B));
    c.drawLine(
        Offset(-u * .12, u * .15),
        Offset(u * .12, u * .12),
        Paint()
          ..color = const Color(0xFF2A1A10)
          ..strokeWidth = u * .04);
    c.restore();
  }

  void _skeleton(Canvas c, double x, double y, double u, double t) {
    final sw = sin(t * 4) * u * .07, j = max(0.0, sin(t * 10)) * u * .05;
    _shadow(c, Offset(x, y), u * .45);
    const bone = Color(0xFFE9E4D0);
    _limb(
        c,
        [
          Offset(x - u * .1, y - u * .6),
          Offset(x - u * .14 + sw, y - u * .3),
          Offset(x - u * .12 + sw, y)
        ],
        u * .06,
        bone);
    _limb(
        c,
        [
          Offset(x + u * .1, y - u * .6),
          Offset(x + u * .14 - sw, y - u * .3),
          Offset(x + u * .12 - sw, y)
        ],
        u * .06,
        bone);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(x, y - u * .6), width: u * .36, height: u * .14),
        Paint()..color = bone);
    _limb(c, [Offset(x, y - u * .62), Offset(x, y - u * 1.15)], u * .06, bone);
    final rib = Paint()
      ..color = bone
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .04;
    for (var i = 0; i < 4; i++) {
      c.drawArc(
          Rect.fromCenter(
              center: Offset(x, y - u * (.78 + i * .1)),
              width: (u * .2 - i * u * .01) * 2,
              height: u * .1),
          pi * .1,
          pi * .8,
          false,
          rib);
    }
    _arms(c, x, y - u * 1.1, u * .2, u * .28, y - u * .6, u * .05, bone, t, 4);
    final b = Paint()..color = bone;
    c.drawCircle(Offset(x, y - u * 1.38), u * .26, b);
    c.drawRect(
        Rect.fromLTWH(x - u * .14, y - u * 1.22 + j, u * .28, u * .1), b);
    final hole = Paint()..color = Colors.black;
    c.drawCircle(Offset(x - u * .1, y - u * 1.4), u * .08, hole);
    c.drawCircle(Offset(x + u * .1, y - u * 1.4), u * .08, hole);
    _eyes(c, Offset(x, y - u * 1.4), u * .03, u * .1, const Color(0xFF3BF0FF));
  }

  void _mummy(Canvas c, double x, double y, double u, double t) {
    final sw = sin(t * 2.5) * u * .06;
    _shadow(c, Offset(x, y), u * .5);
    const ban = Color(0xFFD9CFAE), banD = Color(0xFFB3A77F);
    _limb(c, [Offset(x - u * .12, y - u * .6), Offset(x - u * .12 + sw, y)],
        u * .16, ban);
    _limb(c, [Offset(x + u * .12, y - u * .6), Offset(x + u * .12 - sw, y)],
        u * .16, ban);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - u * .3, y - u * 1.15, u * .6, u * .62),
            Radius.circular(u * .15)),
        Paint()..color = ban);
    final line = Paint()
      ..color = banD
      ..strokeWidth = u * .03;
    for (var i = 0; i < 7; i++) {
      c.drawLine(Offset(x - u * .3, y - u * (1.1 - i * .08)),
          Offset(x + u * .3, y - u * (1.05 - i * .08)), line);
    }
    _arms(
        c, x, y - u * 1.0, u * .28, u * .36, y - u * .5, u * .13, ban, t, 2.5);
    final hand = Offset(x + u * .36 - sin(t * 2.5) * u * .08, y - u * .5);
    c.drawPath(
        Path()
          ..moveTo(hand.dx, hand.dy)
          ..quadraticBezierTo(hand.dx + u * .12 + sin(t * 5) * u * .08,
              hand.dy + u * .15, hand.dx + u * .06, hand.dy + u * .32),
        Paint()
          ..color = ban
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .05);
    c.drawCircle(Offset(x, y - u * 1.38), u * .28, Paint()..color = ban);
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(x - u * .26, y - u * (1.5 - i * .08)),
          Offset(x + u * .26, y - u * (1.45 - i * .08)), line);
    }
    c.drawRect(Rect.fromLTWH(x - u * .2, y - u * 1.43, u * .4, u * .08),
        Paint()..color = Colors.black);
    _eyes(c, Offset(x + u * .08, y - u * 1.39), u * .04, 0,
        const Color(0xFFFFB020));
  }

  void _toxic(Canvas c, double x, double y, double u, double t) {
    final sw = sin(t * 3) * u * .07;
    _shadow(c, Offset(x, y), u * .55);
    const tox = Color(0xFF7DFF3A);
    final glow = Paint()
      ..color = tox.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * .18);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(x, y - u * 1.0), width: u * 1.2, height: u * 1.8),
        glow);
    _limb(c, [Offset(x - u * .12, y - u * .6), Offset(x - u * .14 + sw, y)],
        u * .15, const Color(0xFF2F5A2A));
    _limb(c, [Offset(x + u * .12, y - u * .6), Offset(x + u * .14 - sw, y)],
        u * .15, const Color(0xFF2F5A2A));
    const suit = Color(0xFFE8D23A);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - u * .34, y - u * 1.1, u * .68, u * .58),
            Radius.circular(u * .1)),
        Paint()..color = suit);
    final sym = Offset(x, y - u * .82);
    c.drawCircle(sym, u * .12, Paint()..color = const Color(0xFF222222));
    for (var i = 0; i < 3; i++) {
      c.drawArc(Rect.fromCircle(center: sym, radius: u * .1),
          i * 2 * pi / 3 - .5, 1.0, true, Paint()..color = suit);
    }
    _arms(c, x, y - u * 1.0, u * .32, u * .42, y - u * .5, u * .13, tox, t, 3);
    final skin = Paint()..color = tox;
    c.drawCircle(Offset(x, y - u * 1.35), u * .3, skin);
    for (var i = 0; i < 3; i++) {
      final d = (t * .8 + i * .33) % 1;
      c.drawOval(
          Rect.fromCenter(
              center:
                  Offset(x - u * .15 + i * u * .15, y - u * 1.15 + d * u * .3),
              width: u * .08,
              height: u * .14),
          skin);
    }
    _eyes(
        c, Offset(x, y - u * 1.38), u * .07, u * .12, const Color(0xFFFF2BD6));
    final bub = Paint()..color = tox.withValues(alpha: 0.6);
    for (var i = 0; i < 4; i++) {
      final d = (t * .5 + i * .25) % 1;
      c.drawCircle(
          Offset(x + sin(i * 3 + t * 2) * u * .4, y - u * (1.7 + d * .25)),
          u * (.04 + .03 * (1 - d)),
          bub);
    }
  }

  void _chibi(Canvas c, double x, double y, double u, double t) {
    final b = (sin(t * 4)).abs() * u * .08;
    _shadow(c, Offset(x, y), u * .45);
    const legs = Color(0xFF3A2D4A);
    _limb(c, [Offset(x - u * .1, y - u * .35), Offset(x - u * .1, y)], u * .13,
        legs);
    _limb(c, [Offset(x + u * .1, y - u * .35), Offset(x + u * .1, y)], u * .13,
        legs);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - u * .22, y - u * .75 - b, u * .44, u * .42),
            Radius.circular(u * .12)),
        Paint()..color = const Color(0xFF2F7FBF));
    _arms(c, x, y - u * .68 - b, u * .2, u * .3, y - u * .38 - b, u * .11,
        _skin, t, 4);
    final head = Offset(x, y - u * 1.15 - b);
    c.drawCircle(head, u * .45, Paint()..color = _skin);
    c.drawArc(
        Rect.fromCircle(
            center: head + Offset(u * .15, -u * .37), radius: u * .17),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFFFF9BB5));
    final white = Paint()..color = Colors.white,
        black = Paint()..color = Colors.black;
    c.drawCircle(head + Offset(-u * .17, 0), u * .13, white);
    c.drawCircle(head + Offset(u * .17, 0), u * .1, white);
    c.drawCircle(head + Offset(-u * .15, u * .02), u * .06, black);
    c.drawCircle(head + Offset(u * .18, u * .01), u * .045, black);
    c.drawPath(
        Path()
          ..moveTo(head.dx - u * .12, head.dy + u * .23)
          ..lineTo(head.dx - u * .04, head.dy + u * .19)
          ..lineTo(head.dx + u * .04, head.dy + u * .23)
          ..lineTo(head.dx + u * .12, head.dy + u * .19),
        Paint()
          ..color = const Color(0xFF224444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * .03);
  }

  @override
  bool shouldRepaint(_ZombiePainter o) =>
      o.ph != ph || o.form != form || o.danger != danger;
}

class _NightPainter extends CustomPainter {
  final double t, bite;
  final int hp;
  _NightPainter({required this.t, required this.hp, required this.bite});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060B1A), Color(0xFF0E1A12), Color(0xFF1A2414)],
          ).createShader(Offset.zero & s));
    // lune
    final moon = Offset(w * 0.82, h * 0.1);
    c.drawCircle(moon, h * 0.16,
        Paint()..color = const Color(0xFFE8F0C8).withValues(alpha: 0.08));
    c.drawCircle(moon, h * 0.06, Paint()..color = const Color(0xFFE8F0C8));
    c.drawCircle(moon + Offset(h * 0.02, -h * 0.01), h * 0.055,
        Paint()..color = const Color(0xFF0A1020));
    // couloirs
    for (var i = 1; i < kZombieLanes; i++) {
      final x = w * i / kZombieLanes;
      c.drawLine(
          Offset(x, h * 0.08),
          Offset(x, h * 0.84),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05)
            ..strokeWidth = 1);
    }
    // tombes au loin
    final r = Random(5);
    for (var i = 0; i < 9; i++) {
      final x = r.nextDouble() * w, y = h * (0.1 + r.nextDouble() * 0.12);
      final g = RRect.fromRectAndCorners(
          Rect.fromCenter(center: Offset(x, y), width: 16, height: 22),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8));
      c.drawRRect(g, Paint()..color = const Color(0xFF2A3326));
    }
    // brume qui dérive
    for (var k = 0; k < 4; k++) {
      final x = ((t * (0.3 + k * 0.1) + k * 0.27) % 1.4 - 0.2) * w;
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x, h * (0.35 + k * 0.12)),
              width: w * 0.6,
              height: h * 0.12),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.04)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
    // ligne de danger
    c.drawLine(
        Offset(0, h * 0.8),
        Offset(w, h * 0.8),
        Paint()
          ..color = Tv.red.withValues(alpha: 0.35 + 0.2 * sin(t * 2 * pi * 6))
          ..strokeWidth = 2);
    // la base : mur de sacs de sable + barbelés
    final base = Rect.fromLTWH(0, h * 0.86, w, h * 0.14);
    c.drawRect(base, Paint()..color = const Color(0xFF3A3424));
    for (var x = 0.0; x < w; x += 26) {
      for (final row in [0, 1]) {
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x + (row * 13), base.top + 2 + row * 11, 24, 10),
                const Radius.circular(5)),
            Paint()
              ..color =
                  row == 0 ? const Color(0xFF8A7A50) : const Color(0xFF7A6A44));
      }
    }
    // vies de la base
    for (var i = 0; i < 5; i++) {
      final o = Offset(w / 2 + (i - 2) * 26, base.top + base.height * 0.62);
      _heart(c, o, 9, i < hp ? const Color(0xFFFF3B4A) : Colors.black54);
    }
    if (bite > 0) {
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.transparent,
                Tv.red.withValues(alpha: 0.55 * (1 - bite))
              ],
              stops: const [0.5, 1],
            ).createShader(Offset.zero & s));
    }
  }

  void _heart(Canvas c, Offset o, double s, Color col) {
    final p = Path()
      ..moveTo(o.dx, o.dy + s * 0.9)
      ..cubicTo(o.dx - s * 1.6, o.dy - s * 0.2, o.dx - s * 0.6, o.dy - s * 1.3,
          o.dx, o.dy - s * 0.4)
      ..cubicTo(o.dx + s * 0.6, o.dy - s * 1.3, o.dx + s * 1.6, o.dy - s * 0.2,
          o.dx, o.dy + s * 0.9);
    c.drawPath(p, Paint()..color = col);
  }

  @override
  bool shouldRepaint(_NightPainter o) => true;
}

class _SplatPainter extends CustomPainter {
  final Offset? at;
  final double t;
  _SplatPainter(this.at, this.t);
  @override
  void paint(Canvas c, Size s) {
    if (at == null || t <= 0) return;
    Burst(at!, const Color(0xFF8BFF3A), count: 26, speed: 0.7, seed: 11)
        .paint(c, s, t);
    final o = Offset(at!.dx * s.width, at!.dy * s.height);
    c.drawCircle(
        o,
        30 * Curves.easeOut.transform(t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - t)
          ..color = Colors.white.withValues(alpha: 1 - t));
  }

  @override
  bool shouldRepaint(_SplatPainter o) => o.t != t || o.at != at;
}
