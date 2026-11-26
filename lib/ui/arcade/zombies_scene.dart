// Zombies : cimetière illustré (fond et 5 zombies fournis par foclabroc,
// maquette `zombies_illustre.html`). Les zombies sortent de la brume au
// fond et avancent en perspective vers la barricade, leur cible sur une
// pancarte ; abattu = flash blanc, recul et giclée ; morsure = la
// barricade encaisse et l'écran rougit. Ambiance sonore en boucle +
// grognements, cris, os, bois (sons choisis par foclabroc).

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../audio.dart';
import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

/// 5 formes, mélangées d'après l'id du zombie.
enum ZombieForm { tramp, skeleton, mummy, toxic, chibi }

ZombieForm zombieForm(int id) =>
    ZombieForm.values[(id * 7 + 3) % ZombieForm.values.length];

/// Images de la scène, chargées une fois (null tant qu'elles ne sont pas
/// prêtes : décor de secours).
class ZombieArt {
  static ui.Image? bg;
  static final sprites = <ZombieForm, ui.Image>{};
  static Future<void>? _loading;
  static bool get ready => bg != null && sprites.length == 5;

  static Future<void> load() => _loading ??= () async {
        Future<ui.Image> one(String name) async {
          final data = await rootBundle.load('assets/zombies/$name');
          final codec =
              await ui.instantiateImageCodec(data.buffer.asUint8List());
          return (await codec.getNextFrame()).image;
        }

        try {
          for (final f in ZombieForm.values) {
            sprites[f] = await one('${f.name}.webp');
          }
          bg = await one('bg.jpg');
        } catch (_) {
          _loading = null;
        }
      }();
}

/// Sons de la scène (`assets/sounds/zombies/`).
class ZombieSounds {
  static const dir = 'sounds/zombies';
  static const music = '$dir/zb_music.ogg';
}

/// Taille de l'image de fond et points de perspective (pixels de l'image).
const _bgW = 1376.0, _bgH = 768.0, _farY = 330.0, _nearY = 615.0;

/// Un zombie affiché : position animée [vy] vers [y], apparition, touche.
class _Z {
  final int id, lane;
  final String label;
  final ZombieForm form;
  final double ph, spd;
  int y;
  double vy, born = 0;
  double hit = 0; // > 0 : abattu (secondes depuis la touche)
  bool splat = false;
  _Z(Zombie z, {bool fresh = true})
      : id = z.id,
        lane = z.lane,
        label = z.label,
        form = zombieForm(z.id),
        ph = (z.id * 2.39) % 10,
        spd = 0.8 + (z.id * 0.37) % 0.6,
        y = z.y,
        vy = z.y.toDouble() {
    if (!fresh) born = 1;
  }
}

class _Part {
  double x, y, vx, vy, r, life;
  final Color color;
  _Part(this.x, this.y, this.vx, this.vy, this.r, this.life, this.color);
}

class ZombiesScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const ZombiesScene({super.key, required this.game, required this.colorOf});
  @override
  State<ZombiesScene> createState() => _ZombiesSceneState();
}

class _ZombiesSceneState extends State<ZombiesScene>
    with SingleTickerProviderStateMixin, ArcadeEvents {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  final _rnd = Random();
  final _zs = <int, _Z>{};
  final _parts = <_Part>[];
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  double _t = 0, _shake = 0, _red = 0, _barHit = 0;
  Size _size = const Size(840, 530);
  int _groan = 0;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    for (final z in zombiesState(game).$1) {
      _zs[z.id] = _Z(z, fresh: false);
    }
    if (!ZombieArt.ready) {
      ZombieArt.load().then((_) {
        if (mounted) _wake();
      });
    }
    Perf.liteNotifier.addListener(_wake);
    AudioService.instance.startLoop(ZombieSounds.music, volume: 1.6);
    _wake();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    Perf.liteNotifier.removeListener(_wake);
    AudioService.instance.stopLoop();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _sfx(String name, {double volume = 0.8, int delayMs = 0}) {
    final path = '${ZombieSounds.dir}/$name.ogg';
    if (delayMs == 0) {
      AudioService.instance.playFile(path, volume: volume);
    } else {
      _timers.add(Timer(Duration(milliseconds: delayMs),
          () => AudioService.instance.playFile(path, volume: volume)));
    }
  }

  /// Quelque chose bouge encore (en mode allégé, le ticker s'arrête quand
  /// tout est immobile).
  bool get _busy =>
      _parts.isNotEmpty ||
      _shake > 0.3 ||
      _red > 0.01 ||
      _barHit > 0.01 ||
      _zs.values
          .any((z) => z.hit > 0 || z.born < 1 || (z.vy - z.y).abs() > .01);

  void _wake() {
    if (!mounted) return;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _repaint.value++;
  }

  void _tick(Duration now) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : min(0.05, (now - _lastTick).inMicroseconds / 1e6);
    _lastTick = now;
    _t += dt;
    for (final z in _zs.values.toList()) {
      z.vy += (z.y - z.vy) * min(1, dt * 1.6);
      if ((z.vy - z.y).abs() < .002) z.vy = z.y.toDouble();
      z.born = min(1, z.born + dt * 1.2);
      if (z.hit > 0) {
        z.hit += dt;
        if (z.hit > .22 && !z.splat) {
          z.splat = true;
          final p = _pos(z);
          _burst(
              p,
              z.form == ZombieForm.skeleton
                  ? const Color(0xFFE9E4D0)
                  : const Color(0xFF7DFF3A),
              26);
        }
        if (z.hit > .3) _zs.remove(z.id);
      }
    }
    for (final q in _parts) {
      q.life -= dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.vy += _size.height * 1.7 * dt;
    }
    _parts.removeWhere((q) => q.life <= 0);
    _shake *= pow(0.86, dt * 60);
    _red *= pow(0.92, dt * 60);
    _barHit *= pow(0.9, dt * 60);
    _repaint.value++;
    if (Perf.lite && !_busy) _ticker.stop();
  }

  /// Position au sol d'un couloir à l'avancée [y] (0 au fond, reach à la
  /// barricade) + échelle de perspective.
  ({double x, double y, double s}) _lanePos(int lane, double y) {
    final w = _size.width, h = _size.height;
    final bgS = max(w / _bgW, h / _bgH), bgY = (h - _bgH * bgS) / 2;
    final far = bgY + _farY * bgS, near = bgY + _nearY * bgS;
    final p = pow((y / kZombieReach).clamp(0.0, 1.2), 1.2).toDouble();
    const n = kZombieLanes - 1;
    final nearX = w * (.12 + lane * .76 / n);
    final farX = w * (.25 + lane * .5 / n);
    return (
      x: farX + (nearX - farX) * p,
      y: far + 20 * bgS + (near - far - 20 * bgS) * p,
      s: .3 + .7 * p
    );
  }

  ({double x, double y, double s}) _pos(_Z z) {
    var p = _lanePos(z.lane, z.vy);
    // 2 zombies dans le même couloir : l'un à gauche, l'autre à droite
    final mates = [
      for (final o in _zs.values)
        if (o.lane == z.lane && o.hit == 0) o
    ]..sort((a, b) => a.y.compareTo(b.y));
    if (mates.length > 1 && mates.contains(z)) {
      final side = mates.indexOf(z).isOdd ? 1 : -1;
      p = (
        x: p.x + side * _size.width * .045 * (.5 + p.s * .5),
        y: p.y,
        s: p.s
      );
    }
    return p;
  }

  void _burst(({double x, double y, double s}) p, Color col, int n) {
    final k = _size.height / 530;
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * 2 * pi,
          v = (120 + _rnd.nextDouble() * 380) * k;
      _parts.add(_Part(
          p.x,
          p.y - 120 * p.s * k,
          cos(a) * v * p.s * 1.5,
          sin(a) * v * p.s - 200 * p.s * k,
          (4 + _rnd.nextDouble() * 10) * (p.s + .3) * k,
          .9 + _rnd.nextDouble() * .5,
          col));
    }
  }

  /// Fait correspondre les zombies affichés à l'état de la partie.
  void _sync() {
    final (horde, _) = zombiesState(game);
    final ev = arcadeEvent(game);
    final ids = {for (final z in horde) z.id};
    for (final z in horde) {
      final s = _zs[z.id];
      if (s == null) {
        _zs[z.id] = _Z(z);
      } else {
        s.y = z.y;
      }
    }
    for (final s in _zs.values.toList()) {
      if (ids.contains(s.id) || s.hit > 0) continue;
      if (ev?['type'] == 'kill' && ev?['id'] == s.id) {
        s.hit = .001;
        _shake = 9;
      } else {
        // arrivé à la barricade
        _zs.remove(s.id);
        _burst(_lanePos(s.lane, kZombieReach.toDouble()),
            const Color(0xFF7A1010), 18);
      }
    }
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'kill':
        final z = _zs[e['id']];
        final p = e['p'] as int;
        final form = z?.form ?? zombieForm(e['id'] as int);
        if (form == ZombieForm.skeleton) {
          _sfx('zb_bones', delayMs: 200);
        } else {
          _sfx('zb_splat', volume: .7, delayMs: 200);
          _sfx('zb_pain', volume: .9, delayMs: 200);
        }
        if (z != null) {
          final at = _pos(z);
          _pops.currentState?.add(Pop(
              'ABATTU !',
              widget.colorOf(p),
              Offset(at.x / _size.width,
                  (at.y - _size.height * .49 * at.s) / _size.height),
              size: 30));
        }
      case 'bite':
        _red = 1;
        _shake = 16;
        _barHit = 1;
        _sfx('zb_wood', volume: 1);
        _sfx('zb_barricade', volume: .5);
        _pops.currentState
            ?.add(Pop('MORSURE !', Tv.red, const Offset(0.5, 0.78), size: 40));
      case 'advance':
        _sfx('zb_groan${(_groan++ + _rnd.nextInt(2)) % 3 + 1}', volume: .8);
        _sfx('zb_wave', volume: .5, delayMs: 700);
    }
    _wake();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    _sync();
    if (_busy) _wake();
    final g = game;
    final (horde, hp) = zombiesState(g);
    final waves = g.settings.goalOrDefault;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ScenePainter(this, _repaint),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: .55),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Text('VAGUE ${min(g.round, waves)} / $waves',
                    style: Tv.title(18, color: const Color(0xFF9BFF5A))),
                const Spacer(),
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.favorite,
                        size: 18,
                        color:
                            i < hp ? const Color(0xFFFF3B4A) : Colors.white24),
                  ),
                const Spacer(),
                Text(plural(horde.length, 'ZOMBIE', 'ZOMBIES'),
                    style: Tv.title(18, color: Colors.white)),
              ]),
            ),
          ),
          Positioned.fill(child: PopLayer(key: _pops)),
        ]);
      }),
    );
  }
}

String plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

class _ScenePainter extends CustomPainter {
  final _ZombiesSceneState st;
  _ScenePainter(this.st, Listenable repaint) : super(repaint: repaint);

  static final _white = Paint()
    ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, k = h / 530;
    final t = st._t, lite = Perf.lite;
    c.save();
    if (st._shake > .3) {
      final r = Random((t * 1000).toInt());
      c.translate((r.nextDouble() - .5) * st._shake * k,
          (r.nextDouble() - .5) * st._shake * k);
    }
    final bgS = max(w / _bgW, h / _bgH);
    final bgX = (w - _bgW * bgS) / 2, bgY = (h - _bgH * bgS) / 2;
    final bg = ZombieArt.bg;
    if (bg != null) {
      c.drawImageRect(
          bg,
          const Rect.fromLTWH(0, 0, _bgW, _bgH),
          Rect.fromLTWH(bgX, bgY, _bgW * bgS, _bgH * bgS),
          Paint()..filterQuality = FilterQuality.medium);
    } else {
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF060B1A), Color(0xFF0E1A12), Color(0xFF2A2418)],
            ).createShader(Offset.zero & s));
    }
    final farY = bgY + _farY * bgS, nearY = bgY + _nearY * bgS;
    // lune qui pulse + brume qui dérive
    if (!lite) {
      final moon = Offset(bgX + 852 * bgS, bgY + 98 * bgS);
      c.drawCircle(
          moon,
          120 * k,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFBEFFDC)
                  .withValues(alpha: .18 + .08 * sin(t * 1.3)),
              const Color(0x00BEFFDC),
            ]).createShader(Rect.fromCircle(center: moon, radius: 120 * k)));
      for (var i = 0; i < 4; i++) {
        final x =
            ((t * (8 + i * 5) * k + i * 260 * k) % (w + 400 * k)) - 200 * k;
        final o = Offset(x, farY + (10 + i * 34) * k);
        final r = Rect.fromCenter(center: o, width: 440 * k, height: 240 * k);
        c.drawOval(
            r,
            Paint()
              ..shader = const RadialGradient(colors: [
                Color(0x2178E6AA),
                Color(0x0078E6AA),
              ]).createShader(r));
      }
    }
    // zombies, du fond vers l'avant
    final labels = <_Label>[];
    final art = ZombieArt.ready;
    final zs = st._zs.values.toList()..sort((a, b) => a.vy.compareTo(b.vy));
    for (final z in zs) {
      final p = st._pos(z);
      final img = ZombieArt.sprites[z.form];
      var zh = 260 * k * p.s * (z.form == ZombieForm.chibi ? .85 : 1);
      final zw = img == null ? zh * .6 : zh * img.width / img.height;
      final ph = (lite ? 0 : t) * 2.6 * z.spd + z.ph, step = sin(ph);
      final bob = cos(ph).abs() * 6 * k * p.s,
          rot = step * .055,
          sq = 1 + step.abs() * .025;
      final alpha = z.born.clamp(0.0, 1.0);
      // ombre au sol
      c.drawOval(
          Rect.fromCenter(
              center: Offset(p.x, p.y), width: zw * .76, height: zh * .1),
          Paint()..color = Colors.black.withValues(alpha: .45 * alpha));
      c.save();
      c.translate(p.x, p.y - bob - z.hit * 60 * k * p.s);
      c.rotate(rot + z.hit * 2);
      c.scale(1 / sq, sq);
      final dst = Rect.fromLTWH(-zw / 2, -zh, zw, zh);
      if (art && img != null) {
        final src =
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final paint = Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(alpha: alpha);
        c.drawImageRect(img, src, dst, paint);
        // éclairci au loin (brume)
        if (p.s < .7) {
          c.drawImageRect(
              img,
              src,
              dst,
              Paint()
                ..colorFilter = ColorFilter.mode(
                    Colors.white.withValues(alpha: alpha * (.7 - p.s) * .9),
                    BlendMode.srcIn));
        }
        if (z.hit > 0) c.drawImageRect(img, src, dst, _white);
      } else {
        c.drawRRect(
            RRect.fromRectAndRadius(dst, Radius.circular(zw * .3)),
            Paint()
              ..color = (z.hit > 0 ? Colors.white : const Color(0xFF5E8A4A))
                  .withValues(alpha: alpha));
      }
      c.restore();
      if (z.hit == 0) {
        labels.add(_Label(z, p.x, p.y - zh - 16 * k * p.s - bob,
            max(14.0, (30 * p.s + 6) * k), p.y - zh));
      }
    }
    // pancartes : les plus proches d'abord ; les autres remontent si elles
    // en recouvrent une déjà posée (petit trait vers la tête)
    labels.sort((a, b) => b.z.vy.compareTo(a.z.vy));
    final placed = <Rect>[];
    for (final l in labels) {
      final tp = TextPainter(
          text: TextSpan(
              text: l.z.label, style: Tv.title(l.fs, color: Colors.white)),
          textDirection: TextDirection.ltr)
        ..layout();
      final tw = tp.width + l.fs * .7, th = l.fs * 1.24;
      var y = l.y;
      bool hits(double y2) => placed.any((q) =>
          (q.center.dx - l.x).abs() < (q.width + tw) / 2 + 2 &&
          (q.center.dy - y2).abs() < (q.height + th) / 2 + 2);
      for (var i = 0; i < 8 && hits(y); i++) {
        y -= th + 3;
      }
      final r = Rect.fromCenter(center: Offset(l.x, y), width: tw, height: th);
      placed.add(r);
      if (y < l.y - 2) {
        c.drawLine(
            Offset(l.x, y + th / 2),
            Offset(l.x, l.head),
            Paint()
              ..color = const Color(0x999BFF5A)
              ..strokeWidth = 1.5);
      }
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
      c.drawRRect(rr, Paint()..color = const Color(0xD9080E08));
      c.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = l.z.y >= kZombieReach - 1
                ? const Color(0xFFFF4A4A)
                : const Color(0xFF9BFF5A));
      tp.paint(c, Offset(l.x - tp.width / 2, y - tp.height / 2));
    }
    // éclats
    for (final q in st._parts) {
      c.drawOval(
          Rect.fromCenter(
              center: Offset(q.x, q.y), width: q.r * 2, height: q.r * 1.6),
          Paint()
            ..color = q.color.withValues(alpha: (q.life * 2).clamp(0.0, 1.0)));
    }
    // barricade qui encaisse
    if (st._barHit > .01) {
      c.drawRect(
          Rect.fromLTRB(0, nearY, w, h),
          Paint()
            ..color =
                const Color(0xFFFF3C28).withValues(alpha: st._barHit * .25));
    }
    c.restore();
    if (st._red > .01) {
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..color = const Color(0xFFC80000).withValues(alpha: st._red * .35));
    }
  }

  @override
  bool shouldRepaint(_ScenePainter o) => false;
}

class _Label {
  final _Z z;
  final double x, y, fs, head;
  _Label(this.z, this.x, this.y, this.fs, this.head);
}
