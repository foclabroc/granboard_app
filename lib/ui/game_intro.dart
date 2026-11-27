import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../players.dart';
import 'dartboard.dart';
import 'game_theme.dart';
import 'theme.dart';
import 'widgets.dart';

/// Intro « retransmission TV » au lancement d'une partie (4 s, maquette
/// `intro_tv.html` choisie par foclabroc) : bandes en biseau, bandeau du jeu
/// (famille, nom, règles + nombre de joueurs), joueurs qui arrivent à droite
/// dans l'ordre de jeu, grande cible discrète qui tourne derrière, « GAME
/// ON ! ». Toucher ou une fléchette = passée. Aussi sur l'écran TV.
class GameIntro {
  GameIntro._();

  /// Faux en test (l'intro couvrirait l'écran de jeu).
  static bool enabled = true;

  /// Réglage « Intro des parties » (pref `game_intro_v1`, envoyé à la TV).
  static final on = ValueNotifier<bool>(true);
  static const _pref = 'game_intro_v1';

  static const duration = Duration(milliseconds: 4000);

  /// L'annonce et le bandeau du 1er joueur attendent la fin de l'intro.
  static const delay = Duration(milliseconds: 3700);

  static OverlayEntry? _entry;
  static bool get showing => _entry != null;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      on.value = p.getBool(_pref) ?? true;
    } catch (_) {}
  }

  static Future<void> set(bool v) async {
    on.value = v;
    try {
      (await SharedPreferences.getInstance()).setBool(_pref, v);
    } catch (_) {}
  }

  /// Vrai si l'intro sera jouée pour [game] (partie pas commencée).
  static bool wants(DartsGame game, {bool? remoteOn}) =>
      enabled && (remoteOn ?? on.value) && game.actionLog.isEmpty;

  static void show(BuildContext context, DartsGame game) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _IntroView(
        data: IntroData.of(game),
        onDone: () {
          if (identical(_entry, entry)) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    // 2 sons choisis par foclabroc sur Pixabay, tirés au hasard
    AudioService.instance
        .playFile(kIntroSounds[_rnd.nextInt(kIntroSounds.length)], volume: .85);
  }

  static final _rnd = Random();

  /// « Energy Stomps Logo » (alexzavesa, 3,3 → 7,4 s) et « Intro Podcast »
  /// (dariocoiro, dès 0,3 s) : le temps fort tombe sur GAME ON (2,7 s).
  static const kIntroSounds = ['sounds/intro.ogg', 'sounds/intro2.ogg'];

  static void hide() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }
}

/// Ce que montre l'intro.
class IntroData {
  final String family;
  final String name;
  final String rules;
  final List<({String id, String name, Color color})> players;
  final Color col;
  final Color col2;
  const IntroData(
      {required this.family,
      required this.name,
      required this.rules,
      required this.players,
      required this.col,
      required this.col2});

  factory IntroData.of(DartsGame g) {
    final skin = GameSkins.ofGame(g);
    final family = switch (g) {
      MatchGame() => 'MEDLEY',
      PracticeGame() => kPracticeInfo[g.settings.kind]?.party == true
          ? 'PARTY'
          : 'ENTRAÎNEMENT',
      _ => g.kind == 'cricket' ? 'CRICKET' : '01',
    };
    final name = g is MatchGame ? 'MEDLEY' : g.title.toUpperCase();
    final store = PlayerStore.instance;
    return IntroData(
      family: family,
      name: name,
      rules: g.rulesLabel.toUpperCase(),
      players: [
        for (final p in g.players)
          (id: p.id, name: p.name, color: store.colorOf(p.id))
      ],
      col: skin.accent,
      col2: skin.glow,
    );
  }

  String get count =>
      '${players.length} JOUEUR${players.length > 1 ? 'S' : ''}';
}

class _IntroView extends StatefulWidget {
  final IntroData data;
  final VoidCallback onDone;
  const _IntroView({required this.data, required this.onDone});

  @override
  State<_IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<_IntroView>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: GameIntro.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDone,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * GameIntro.duration.inMilliseconds / 1000;
            final out = _eIn(_prog(t, 3.5, 4.0));
            return Stack(children: [
              // fond plein écran (bandes) : déborde de la zone 16:9
              Positioned.fill(
                  child:
                      CustomPaint(painter: _BgPainter(t, out, d.col, d.col2))),
              // contenu dessiné en 960 × 540 puis mis à l'échelle
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 960,
                    height: 540,
                    child: Stack(clipBehavior: Clip.none, children: [
                      _bigBoard(t, out),
                      Positioned.fill(
                          child:
                              CustomPaint(painter: _TitlePainter(t, out, d))),
                      ..._plates(t, out, d),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  /// Grande cible discrète qui tourne lentement derrière les joueurs.
  Widget _bigBoard(double t, double out) {
    const r = 440.0;
    return Positioned(
      left: 960 * .66 - r,
      top: 270 - r,
      width: r * 2,
      height: r * 2,
      child: Opacity(
        opacity: (.11 * _prog(t, 0, .7) * (1 - out)).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -.3 + t * .06,
          child: Transform.scale(
            scale: 1 + out * .3,
            child: RepaintBoundary(
                child: DartboardPreview(
                    skin: BoardSkin.current.value, size: r * 2)),
          ),
        ),
      ),
    );
  }

  /// Joueurs à droite, un par un, dans l'ordre de jeu.
  List<Widget> _plates(double t, double out, IntroData d) {
    final ps = d.players;
    final h = min(56.0, (540 - 90) / ps.length - 8);
    final top = 270 - ps.length * (h + 8) / 2;
    const x0 = 960 * .66, w = 960 * .3;
    return [
      Positioned(
        left: x0,
        top: top - 34,
        child: Opacity(
          opacity: _prog(t, 1.1, 1.3) * (1 - out),
          child: Text('ORDRE DE JEU', style: Tv.title(22, color: d.col)),
        ),
      ),
      for (var i = 0; i < ps.length; i++)
        () {
          final q = _eOut(_prog(t, 1.2 + i * .12, 1.55 + i * .12));
          final p = ps[i];
          return Positioned(
            left: x0 - 26 + (1 - q) * 360 + out * 400,
            top: top + i * (h + 8),
            width: w + 26,
            height: h,
            child: Opacity(
              opacity: (q * (1 - out)).clamp(0.0, 1.0),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      textAlign: TextAlign.center,
                      style: Tv.title(h * .4, color: Colors.white54)),
                ),
                Expanded(child: _Plate(p.id, p.name, p.color, h)),
              ]),
            ),
          );
        }(),
    ];
  }
}

/// Cartouche d'un joueur : biseau, liseré et dégradé à sa couleur, photo,
/// nom et rang.
class _Plate extends StatelessWidget {
  final String id;
  final String name;
  final Color color;
  final double h;
  const _Plate(this.id, this.name, this.color, this.h);

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-.18),
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.lerp(const Color(0xE6080A0F), color, .45)!,
            const Color(0xD9080A0F),
          ]),
          border: Border(left: BorderSide(color: color, width: 7)),
        ),
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Transform(
          transform: Matrix4.skewX(.18),
          alignment: Alignment.center,
          child: Row(children: [
            PlayerAvatar(name: name, color: color, size: h * .72, id: id),
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
                        style: Tv.title(h * .44, color: Colors.white)),
                  ),
                  if (h >= 34) RankChip(id, size: h * .2),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

double _prog(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);
double _eOut(double x) => 1 - pow(1 - x, 3).toDouble();
double _eIn(double x) => x * x * x;
double _eExpo(double x) => x >= 1 ? 1 : 1 - pow(2, -10 * x).toDouble();
double _eBack(double x, [double s = 1.8]) =>
    1 + (s + 1) * pow(x - 1, 3) + s * pow(x - 1, 2);

/// Fond : noir teinté + 5 bandes en biseau qui traversent l'écran.
class _BgPainter extends CustomPainter {
  final double t, out;
  final Color col, col2;
  _BgPainter(this.t, this.out, this.col, this.col2);

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..color = const Color(0xFF05060A));
    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            colors: [col.withValues(alpha: .22), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r));
    final k = s.height / 540;
    for (var i = 0; i < 5; i++) {
      final p = _eExpo(_prog(t, .05 + i * .05, .55 + i * .05));
      final x = -s.width + p * s.width * 2.2 - out * s.width * 2;
      c.save();
      c.translate(x, 0);
      c.transform(Float64List.fromList(
          [1, 0, 0, 0, -.45, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
      c.drawRect(
          Rect.fromLTWH(i * 90 * k, 0, (20 + i * 6) * k, s.height),
          Paint()
            ..color = i.isOdd
                ? col.withValues(alpha: .9)
                : col2.withValues(alpha: .5));
      c.restore();
    }
    // vignette
    c.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: .5)],
            stops: const [.45, 1],
          ).createShader(r));
  }

  @override
  bool shouldRepaint(_BgPainter o) => o.t != t;
}

/// Bandeau du jeu (gauche), règles + nombre de joueurs, reflet, GAME ON.
class _TitlePainter extends CustomPainter {
  final double t, out;
  final IntroData d;
  _TitlePainter(this.t, this.out, this.d);

  static const cx = 960 * .34, cy = 230.0, bw0 = 960 * .56;

  TextPainter _tp(String s, TextStyle st) => TextPainter(
      text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)
    ..layout();

  void _center(Canvas c, TextPainter p, Offset o) =>
      p.paint(c, o - Offset(p.width / 2, p.height / 2));

  @override
  void paint(Canvas c, Size s) {
    final a = 1 - out;
    // bandeau en biseau qui s'ouvre
    final p = _eExpo(_prog(t, .35, .85)), bw = bw0 * p;
    c.save();
    c.translate(cx, cy);
    c.transform(Float64List.fromList(
        [1, 0, 0, 0, -.18, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
    final band = Rect.fromLTWH(-bw / 2, -62, max(bw, .1), 124);
    c.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(colors: [
            d.col.withValues(alpha: a),
            d.col2.withValues(alpha: a)
          ]).createShader(band));
    c.drawRect(Rect.fromLTWH(-bw / 2, 62, bw, 44),
        Paint()..color = Colors.black.withValues(alpha: a));
    c.restore();
    // famille
    final f = _prog(t, .55, .8);
    if (f > 0) {
      _center(
          c,
          _tp(d.family, Tv.title(28, color: d.col2.withValues(alpha: f * a))),
          Offset(cx, cy - 92 - (1 - f) * 20));
    }
    // nom du jeu qui se dévoile de gauche à droite
    final tp = _eOut(_prog(t, .6, 1.1));
    if (tp > 0) {
      var px = 118.0;
      var title = _tp(d.name, Tv.title(px, color: Colors.white));
      if (title.width > bw0 * .86) {
        px *= bw0 * .86 / title.width;
        title = _tp(d.name, Tv.title(px, color: Colors.white));
      }
      final shadow = _tp(d.name, Tv.title(px, color: Colors.black));
      c.save();
      c.clipRect(Rect.fromLTWH(cx - bw0 / 2, cy - 70, bw0 * tp, 140));
      if (a < 1) {
        c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: a));
      }
      _center(c, shadow, const Offset(cx + 4, cy - 2));
      _center(c, title, const Offset(cx, cy - 6));
      if (a < 1) c.restore();
      c.restore();
    }
    // règles · N JOUEURS
    final rp = _prog(t, 1.0, 1.4);
    if (rp > 0) {
      final rules =
          d.rules.length > 34 ? '${d.rules.substring(0, 33)}…' : d.rules;
      final line = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(children: [
            TextSpan(
                text: rules.isEmpty ? '' : '$rules  ·  ',
                style: Tv.title(24,
                    color: Colors.white.withValues(alpha: rp * a))),
            TextSpan(
                text: d.count,
                style: Tv.title(24, color: d.col.withValues(alpha: rp * a))),
          ]))
        ..layout(maxWidth: bw0 - 20);
      _center(c, line, const Offset(cx, cy + 84));
    }
    // reflet qui balaie le bandeau
    final sw = _prog(t, 1.6, 2.2);
    if (sw > 0 && sw < 1) {
      final x = cx - bw0 / 2 - 100 + sw * (bw0 + 200);
      const r = Rect.fromLTWH(cx - bw0 / 2 - 60, cy - 62, bw0 + 120, 124);
      c.drawRect(
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: .35),
              Colors.white.withValues(alpha: 0),
            ], stops: [
              ((x - 70 - r.left) / r.width).clamp(0.0, 1.0),
              ((x - r.left) / r.width).clamp(0.0, 1.0),
              ((x + 70 - r.left) / r.width).clamp(0.0, 1.0),
            ]).createShader(r));
    }
    // GAME ON !
    final gp = _prog(t, 2.7, 3.0);
    if (gp > 0) {
      final sc = _eBack(gp, 3);
      c.save();
      c.translate(cx, cy + 160);
      c.scale(sc, sc);
      final go = _tp(
          'GAME ON !',
          Tv.title(50, color: d.col.withValues(alpha: a)).copyWith(shadows: [
            Shadow(color: d.col.withValues(alpha: a), blurRadius: 25)
          ]));
      _center(c, go, Offset.zero);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_TitlePainter o) => o.t != t;
}
