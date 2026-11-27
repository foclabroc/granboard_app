// Fight Club : ring illustré (assets/fight/bg.jpg) et un boxeur détouré par
// joueur (garde / coup de poing, images Gemini) ; étiquette par combattant
// en haut (photo, barre de vie avec traînée rouge, numéros) ; coup : le
// boxeur frappe et l'autre recule (éclair rouge), soin (halo vert), onde de
// choc du bull, K.O. (le boxeur tombe + tampon). Sans les images (tests) :
// l'ancien ring dessiné.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/practice.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

/// Images de la scène, chargées une fois.
class FightArt {
  static ui.Image? bg;
  static final guard = <ui.Image>[], punch = <ui.Image>[];
  static Future<void>? _loading;
  static bool get ready => bg != null && punch.length == kBoxers.length;

  /// Boxeurs (assets/fight/<nom>_guard|punch.webp), tournés vers la droite.
  static const kBoxers = ['beard', 'mohawk', 'pony', 'heavy'];

  static Future<void> load() => _loading ??= () async {
        Future<ui.Image> one(String name) async {
          final data = await rootBundle.load('assets/fight/$name');
          final codec =
              await ui.instantiateImageCodec(data.buffer.asUint8List());
          return (await codec.getNextFrame()).image;
        }

        try {
          final g = <ui.Image>[], p = <ui.Image>[];
          for (final b in kBoxers) {
            g.add(await one('${b}_guard.webp'));
            p.add(await one('${b}_punch.webp'));
          }
          guard
            ..clear()
            ..addAll(g);
          punch
            ..clear()
            ..addAll(p);
          bg = await one('bg.jpg');
        } catch (_) {
          _loading = null;
        }
      }();
}

class FightScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const FightScene({super.key, required this.game, required this.colorOf});
  @override
  State<FightScene> createState() => _FightSceneState();
}

class _FightSceneState extends State<FightScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _hit = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _blast = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  int? _victim;
  int? _healed;
  int? _attacker;

  @override
  void initState() {
    super.initState();
    startAmbient();
    if (!FightArt.ready) {
      FightArt.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Taille de la scène au dernier affichage (pour placer les textes).
  Size _sz = const Size(800, 450);

  Offset _cardCenter(int i) {
    if (FightArt.ready) {
      final sl = _Slot.of(i, game.players.length);
      final m = _Map(_sz);
      final head = m.at(Offset(sl.x, sl.y - _Slot.boxerH * sl.k * .95));
      return Offset(head.dx / _sz.width, head.dy / _sz.height + .1);
    }
    final n = game.players.length;
    if (n == 2) return Offset(i == 0 ? 0.25 : 0.75, 0.52);
    return Offset(i.isEven ? 0.27 : 0.73, i < 2 ? 0.3 : 0.74);
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'hit':
        _victim = e['o'] as int;
        _attacker = e['p'] as int?;
        _healed = null;
        _hit.forward(from: 0);
        _pops.currentState?.add(Pop(
            e['m'] == 3 ? 'UPPERCUT ! -${e['dmg']}' : '-${e['dmg']}',
            const Color(0xFFFF5A4A),
            _cardCenter(_victim!) - const Offset(0, 0.12),
            size: e['m'] == 3 ? 40 : 34));
      case 'heal':
        _healed = e['p'] as int;
        _victim = null;
        _attacker = null;
        _hit.forward(from: 0);
        _pops.currentState?.add(Pop('+${e['v']} PV', const Color(0xFF6BFF8A),
            _cardCenter(_healed!) - const Offset(0, 0.12)));
      case 'blast':
        _blast.forward(from: 0);
        _pops.currentState?.add(Pop('ONDE DE CHOC -${e['dmg']}',
            const Color(0xFFFFD34F), const Offset(0.5, 0.5),
            size: 38));
    }
  }

  @override
  void dispose() {
    _hit.dispose();
    _blast.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    if (FightArt.ready) return _illustrated(context);
    final g = game;
    final nums = fightNumbers(g);
    final maxHp = g.settings.goalOrDefault;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, c) {
        final n = g.players.length;
        final cw = n == 2 ? c.maxWidth * 0.4 : c.maxWidth * 0.44;
        final ch = n == 2 ? c.maxHeight * 0.62 : c.maxHeight * 0.42;
        return Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([ambient, _blast]),
              builder: (context, _) => CustomPaint(
                  painter: _RingPainter(
                      ambient.value, _blast.isAnimating ? _blast.value : 0)),
            ),
          ),
          if (n == 2)
            Positioned.fill(
              child: Center(
                child: Text('VS',
                    style: Tv.title(64, color: const Color(0xFFE53935))
                        .copyWith(fontStyle: FontStyle.italic, shadows: const [
                      Shadow(blurRadius: 16, color: Colors.black)
                    ])),
              ),
            ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: _cardCenter(i).dx * c.maxWidth - cw / 2,
              top: _cardCenter(i).dy * c.maxHeight - ch / 2,
              width: cw,
              height: ch,
              child: AnimatedBuilder(
                animation: _hit,
                builder: (context, child) {
                  final t = _hit.isAnimating ? _hit.value : 0.0;
                  final off = _victim == i ? shake(t, amp: 10) : Offset.zero;
                  return Transform.translate(offset: off, child: child);
                },
                child: _FighterCard(
                  key: ValueKey('fight-$i'),
                  id: g.players[i].id,
                  name: g.players[i].name,
                  color: widget.colorOf(i),
                  hp: g.stateOf(i).score,
                  maxHp: maxHp,
                  numbers: nums.isEmpty ? const [] : nums[i],
                  current: i == g.current && !g.finished,
                  out: g.stateOf(i).out,
                  flash: _hit,
                  flashColor: _victim == i
                      ? const Color(0xFFFF3B30)
                      : _healed == i
                          ? const Color(0xFF4CFF80)
                          : null,
                ),
              ),
            ),
          Positioned.fill(child: PopLayer(key: _pops)),
        ]);
      }),
    );
  }

  /// Ring illustré : boxeurs sur le ring, étiquettes en haut.
  Widget _illustrated(BuildContext context) {
    final g = game;
    final nums = fightNumbers(g);
    final maxHp = g.settings.goalOrDefault;
    final n = g.players.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, c) {
        _sz = c.biggest;
        final tagW =
            n == 2 ? c.maxWidth * 0.36 : (c.maxWidth - 10.0 * (n + 1)) / n;
        final tagH = min(c.maxHeight * 0.25, 92.0);
        return Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([ambient, _hit, _blast]),
              builder: (context, _) => CustomPaint(
                painter: _ArenaPainter(
                  t: ambient.value,
                  hit: _hit.isAnimating ? _hit.value : 1,
                  blast: _blast.isAnimating ? _blast.value : 0,
                  n: n,
                  current: g.finished ? -1 : g.current,
                  out: [for (var i = 0; i < n; i++) g.stateOf(i).out],
                  colors: [for (var i = 0; i < n; i++) widget.colorOf(i)],
                  victim: _victim,
                  attacker: _attacker,
                  healed: _healed,
                ),
              ),
            ),
          ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: n == 2
                  ? (i == 0 ? 10 : c.maxWidth - tagW - 10)
                  : 10 + i * (tagW + 10),
              top: 8,
              width: tagW,
              height: tagH,
              child: AnimatedBuilder(
                animation: _hit,
                builder: (context, child) {
                  final t = _hit.isAnimating ? _hit.value : 0.0;
                  final off = _victim == i ? shake(t, amp: 6) : Offset.zero;
                  return Transform.translate(offset: off, child: child);
                },
                child: _FighterTag(
                  key: ValueKey('fight-$i'),
                  id: g.players[i].id,
                  name: g.players[i].name,
                  color: widget.colorOf(i),
                  hp: g.stateOf(i).score,
                  maxHp: maxHp,
                  numbers: nums.isEmpty ? const [] : nums[i],
                  current: i == g.current && !g.finished,
                  out: g.stateOf(i).out,
                ),
              ),
            ),
          if (n == 2)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              height: tagH,
              child: Center(
                child: Text('VS',
                    style: Tv.title(min(46, tagH * .6),
                            color: const Color(0xFFE53935))
                        .copyWith(fontStyle: FontStyle.italic, shadows: const [
                      Shadow(blurRadius: 12, color: Colors.black)
                    ])),
              ),
            ),
          Positioned.fill(child: PopLayer(key: _pops)),
        ]);
      }),
    );
  }
}

/// Passage pixels de l'image de fond (1376 × 768) → écran (« cover »).
class _Map {
  static const w = 1376.0, h = 768.0;
  final double s, dx, dy;
  _Map._(this.s, this.dx, this.dy);
  factory _Map(Size z) {
    // « cover » zoomé × 1,2 sur le ring (centre de l'image, y 470 aux 64 %)
    final s = max(z.width / w, z.height / h) * 1.2;
    final dx = (z.width / 2 - w / 2 * s).clamp(z.width - w * s, 0.0);
    final dy = (z.height * .64 - 470 * s).clamp(z.height - h * s, 0.0);
    return _Map._(s, dx, dy);
  }
  Offset at(Offset p) => Offset(dx + p.dx * s, dy + p.dy * s);
}

/// Place d'un boxeur sur le ring (pixels de l'image) : pieds en (x, y),
/// échelle k, tourné vers la droite ou non.
class _Slot {
  final double x, y, k;
  final bool right;
  const _Slot(this.x, this.y, this.k, this.right);

  /// Hauteur d'un boxeur au premier plan (pixels de l'image).
  static const boxerH = 330.0;

  static _Slot of(int i, int n) {
    if (n <= 2) {
      return i == 0
          ? const _Slot(570, 556, 1, true)
          : const _Slot(806, 556, 1, false);
    }
    return switch (i) {
      0 => const _Slot(560, 562, 1, true),
      1 => const _Slot(816, 562, 1, false),
      2 => n == 3
          ? const _Slot(688, 506, .8, true)
          : const _Slot(470, 506, .8, true),
      _ => const _Slot(906, 506, .8, false),
    };
  }
}

class _ArenaPainter extends CustomPainter {
  final double t, hit, blast;
  final int n, current;
  final List<bool> out;
  final List<Color> colors;
  final int? victim, attacker, healed;
  _ArenaPainter(
      {required this.t,
      required this.hit,
      required this.blast,
      required this.n,
      required this.current,
      required this.out,
      required this.colors,
      required this.victim,
      required this.attacker,
      required this.healed});

  @override
  void paint(Canvas c, Size z) {
    final bg = FightArt.bg!;
    final m = _Map(z);
    c.drawImageRect(
        bg,
        const Rect.fromLTWH(0, 0, _Map.w, _Map.h),
        Rect.fromLTWH(m.dx, m.dy, _Map.w * m.s, _Map.h * m.s),
        Paint()..filterQuality = FilterQuality.medium);
    // voile sombre en haut (étiquettes lisibles)
    c.drawRect(
        Offset.zero & z,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xAA000000), Color(0x00000000)],
            stops: [0, .4],
          ).createShader(Offset.zero & z));
    // du fond vers l'avant
    final order = [for (var i = 0; i < n; i++) i]
      ..sort((a, b) => _Slot.of(a, n).y.compareTo(_Slot.of(b, n).y));
    for (final i in order) {
      _boxer(c, m, i);
    }
    if (blast > 0) {
      final o = m.at(const Offset(688, 500));
      final r = blast * max(z.width, z.height) * 0.8;
      c.drawCircle(
          o,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18 * (1 - blast)
            ..color = const Color(0xFFFFD34F).withValues(alpha: 1 - blast));
      if (blast < .2) {
        c.drawRect(Offset.zero & z,
            Paint()..color = Colors.white.withValues(alpha: .25 * (1 - blast)));
      }
    }
  }

  void _boxer(Canvas c, _Map m, int i) {
    final sl = _Slot.of(i, n);
    final kind = i % FightArt.kBoxers.length;
    final ko = out[i];
    final striking = attacker == i && hit < .6;
    final img = striking ? FightArt.punch[kind] : FightArt.guard[kind];
    final scale = _Slot.boxerH * sl.k / img.height * m.s;
    final w = img.width * scale, h = img.height * scale;
    // ancrage sur le corps (le bras tendu dépasse devant)
    final body = striking ? .36 : .5;
    var foot = m.at(Offset(sl.x, sl.y));
    final dir = sl.right ? 1.0 : -1.0;
    // garde qui sautille
    if (!ko) foot += Offset(0, -3 * m.s * sin(t * 2 * pi * 8 + i * 1.7).abs());
    if (striking) foot += Offset(dir * 26 * m.s * sin(pi * hit / .6), 0);
    if (victim == i && hit < 1) {
      foot += Offset(-dir * 22 * m.s * (1 - hit) + shake(hit, amp: 4).dx, 0);
    }
    // halo au sol : couleur du joueur, plus vif pour le joueur en cours
    final col = colors[i];
    final cur = i == current;
    c.drawOval(
        Rect.fromCenter(
            center: foot, width: w * (cur ? .95 : .7), height: 18 * m.s * sl.k),
        Paint()
          ..color = col.withValues(alpha: ko ? .15 : (cur ? .75 : .35))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.save();
    c.translate(foot.dx, foot.dy);
    if (ko) {
      // tombe en arrière (animé pendant le coup qui l'a mis K.O.)
      final k = victim == i && hit < 1 ? Curves.easeIn.transform(hit) : 1.0;
      c.rotate(-dir * pi / 2 * .92 * k);
    }
    if (!sl.right) c.scale(-1, 1);
    final dst = Rect.fromLTWH(-w * body, -h, w, h);
    final p = Paint()..filterQuality = FilterQuality.medium;
    if (ko) p.color = Colors.white.withValues(alpha: .8);
    c.drawImageRect(
        img, Rect.fromLTWH(0, 0, img.width * 1.0, img.height * 1.0), dst, p);
    // éclair rouge (coup reçu) / vert (soin)
    final flash = victim == i
        ? const Color(0xFFFF3B30)
        : healed == i
            ? const Color(0xFF4CFF80)
            : null;
    if (flash != null && hit < 1) {
      c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width * 1.0, img.height * 1.0),
          dst,
          Paint()
            ..colorFilter = ColorFilter.mode(
                flash.withValues(alpha: (1 - hit) * .7), BlendMode.srcATop));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_ArenaPainter o) => true;
}

/// Étiquette d'un combattant (au-dessus du ring) : photo, nom, PV, barre,
/// numéros.
class _FighterTag extends StatelessWidget {
  final String id, name;
  final Color color;
  final int hp, maxHp;
  final List<int> numbers;
  final bool current, out;
  const _FighterTag(
      {super.key,
      required this.id,
      required this.name,
      required this.color,
      required this.hp,
      required this.maxHp,
      required this.numbers,
      required this.current,
      required this.out});

  @override
  Widget build(BuildContext context) {
    final frac = (hp / maxHp).clamp(0.0, 1.0);
    final barColor = frac > 0.5
        ? const Color(0xFF4CD964)
        : frac > 0.25
            ? const Color(0xFFFFB02E)
            : const Color(0xFFFF3B30);
    return LayoutBuilder(builder: (context, c) {
      final av = min(c.maxHeight * .5, 40.0);
      return Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: current ? Colors.white : color.withValues(alpha: .8),
                width: current ? 2.2 : 1.4),
            boxShadow: [
              if (current)
                BoxShadow(color: color.withValues(alpha: .6), blurRadius: 16),
            ],
          ),
          child: Opacity(
            opacity: out ? .5 : 1,
            child: Column(children: [
              Expanded(
                child: Row(children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: PlayerAvatar(
                        id: id, name: name, color: color, size: av),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(name.toUpperCase(),
                          maxLines: 1,
                          style: Tv.title(18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('$hp', style: Tv.title(20, color: barColor)),
                ]),
              ),
              const SizedBox(height: 3),
              SizedBox(height: 9, child: _HpBar(frac: frac, color: barColor)),
              const SizedBox(height: 3),
              SizedBox(
                height: min(18, c.maxHeight * .22),
                child: Row(children: [
                  for (final n in numbers)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: color),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          child: Text('$n',
                              style: Tv.title(14, color: Colors.white)),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        if (out)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -0.2,
                  child: Text('K.O.',
                      style: Tv.title(30, color: const Color(0xFFFF3B30))
                          .copyWith(shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black)
                      ])),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _FighterCard extends StatelessWidget {
  final String id, name;
  final Color color;
  final int hp, maxHp;
  final List<int> numbers;
  final bool current, out;
  final Animation<double> flash;
  final Color? flashColor;
  const _FighterCard(
      {super.key,
      required this.id,
      required this.name,
      required this.color,
      required this.hp,
      required this.maxHp,
      required this.numbers,
      required this.current,
      required this.out,
      required this.flash,
      required this.flashColor});

  @override
  Widget build(BuildContext context) {
    final frac = (hp / maxHp).clamp(0.0, 1.0);
    final barColor = frac > 0.5
        ? const Color(0xFF4CD964)
        : frac > 0.25
            ? const Color(0xFFFFB02E)
            : const Color(0xFFFF3B30);
    return LayoutBuilder(builder: (context, c) {
      final av = min(c.maxHeight * 0.42, c.maxWidth * 0.36);
      return Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: out ? 0.15 : 0.55),
                Colors.black.withValues(alpha: 0.8)
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: current ? Colors.white : color.withValues(alpha: 0.7),
                width: current ? 2.5 : 1.5),
            boxShadow: [
              if (current)
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 22),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Opacity(
            opacity: out ? 0.45 : 1,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 12)
                          ],
                        ),
                        child: PlayerAvatar(
                            id: id, name: name, color: color, size: av),
                      ),
                      const SizedBox(width: 10),
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
                                  style: Tv.title(22, color: Colors.white)),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('$hp PV',
                                  style: Tv.title(30, color: barColor)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _HpBar(frac: frac, color: barColor),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final n in numbers)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color),
                          ),
                          alignment: Alignment.center,
                          child: Text('$n',
                              style: Tv.title(20, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // éclair du coup / halo du soin
        if (flashColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: flash,
                builder: (context, _) {
                  final t = flash.value;
                  final a = t <= 0 || t >= 1 ? 0.0 : (1 - t) * 0.6;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: flashColor!.withValues(alpha: a),
                    ),
                  );
                },
              ),
            ),
          ),
        if (out)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 2.4, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Transform.rotate(
                    angle: -0.25,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFFF3B30), width: 4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('K.O.',
                          style: Tv.title(46, color: const Color(0xFFFF3B30))),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Barre de vie : la partie perdue reste rouge un instant puis se vide.
class _HpBar extends StatelessWidget {
  final double frac;
  final Color color;
  const _HpBar({required this.frac, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: LayoutBuilder(builder: (context, c) {
        return Stack(children: [
          Container(
            decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(7)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: frac),
            duration: const Duration(milliseconds: 1100),
            curve: const Interval(0.45, 1, curve: Curves.easeOut),
            builder: (context, v, _) => Container(
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C),
                  borderRadius: BorderRadius.circular(7)),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: frac),
            duration: const Duration(milliseconds: 280),
            builder: (context, v, _) => Container(
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t, blast;
  _RingPainter(this.t, this.blast);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0A0505));
    // tapis du ring en perspective
    final mat = Path()
      ..moveTo(w * 0.08, h * 0.98)
      ..lineTo(w * 0.92, h * 0.98)
      ..lineTo(w * 0.78, h * 0.12)
      ..lineTo(w * 0.22, h * 0.12)
      ..close();
    c.drawPath(
        mat,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A1414), Color(0xFF5A1C1C)],
          ).createShader(Offset.zero & s));
    // cordes
    for (var k = 0; k < 3; k++) {
      final y0 = h * (0.12 - k * 0.035), y1 = h * (0.98 - k * 0.05);
      final rope = Paint()
        ..color = [
          const Color(0xFFE53935),
          Colors.white,
          const Color(0xFF1E5AE5)
        ][k]
            .withValues(alpha: 0.75)
        ..strokeWidth = 3;
      c.drawLine(Offset(w * 0.22, y0), Offset(w * 0.08, y1), rope);
      c.drawLine(Offset(w * 0.78, y0), Offset(w * 0.92, y1), rope);
      c.drawLine(Offset(w * 0.22, y0), Offset(w * 0.78, y0), rope);
    }
    // projecteurs qui balaient
    for (final (x, ph) in [(0.25, 0.0), (0.75, 1.7)]) {
      final a = sin(t * 2 * pi * 2 + ph) * 0.25;
      final o = Offset(w * x, -10);
      final e = Offset(w * x + sin(a) * h, h);
      c.drawPath(
          Path()
            ..moveTo(o.dx - 4, o.dy)
            ..lineTo(o.dx + 4, o.dy)
            ..lineTo(e.dx + 110, e.dy)
            ..lineTo(e.dx - 110, e.dy)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0)
              ],
            ).createShader(Offset.zero & s));
    }
    // onde de choc
    if (blast > 0) {
      final r = blast * max(w, h) * 0.8;
      c.drawCircle(
          Offset(w / 2, h / 2),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18 * (1 - blast)
            ..color = const Color(0xFFFFD34F).withValues(alpha: 1 - blast));
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..color = Colors.white
                .withValues(alpha: 0.25 * (1 - blast) * (blast < 0.2 ? 1 : 0)));
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.blast != blast;
}
