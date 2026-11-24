// Outils communs aux écrans des jeux « arcade » (Party v0.6.28) : lecture
// du dernier évènement de la partie, textes qui s'envolent, billes
// brillantes, bandeau des scores.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import '../widgets.dart';

/// Dernier évènement posé par les règles (`shared['ev']`).
Map<String, dynamic>? arcadeEvent(PracticeGame g) =>
    (g.shared['ev'] as Map?)?.cast<String, dynamic>();

/// État d'une scène qui anime les nouveaux évènements une seule fois
/// (pas au rejeu, pas à l'ouverture).
mixin ArcadeEvents<T extends StatefulWidget> on State<T> {
  PracticeGame get game;
  int? _seen;

  @override
  void initState() {
    super.initState();
    _seen = arcadeEvent(game)?['n'] as int?;
  }

  /// À appeler dans build : nouvel évènement → [onEvent] après l'image.
  void checkEvent() {
    final e = arcadeEvent(game);
    final n = e?['n'] as int?;
    if (n == null || n == _seen) return;
    _seen = n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onEvent(e!);
    });
  }

  void onEvent(Map<String, dynamic> e);
}

/// Animation continue (décor) coupée quand l'écran est allégé (TV).
mixin AmbientTicker<T extends StatefulWidget> on State<T>, TickerProvider {
  late final AnimationController ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));

  void startAmbient() {
    _applyLite();
    Perf.liteNotifier.addListener(_applyLite);
  }

  void _applyLite() {
    if (Perf.lite) {
      ambient.stop();
      ambient.value = 0.3;
    } else if (!ambient.isAnimating) {
      ambient.repeat();
    }
  }

  void stopAmbient() {
    Perf.liteNotifier.removeListener(_applyLite);
    ambient.dispose();
  }
}

/// Un texte qui monte et s'efface (« +60 », « K.O. »…).
class Pop {
  final String text;
  final Color color;
  final Offset at; // fraction de la scène (0-1)
  final double size;
  final int born;
  Pop(this.text, this.color, this.at, {this.size = 34})
      : born = DateTime.now().millisecondsSinceEpoch;
}

/// Couche des textes qui s'envolent : [add] puis elle se redessine seule.
class PopLayer extends StatefulWidget {
  const PopLayer({super.key});
  @override
  State<PopLayer> createState() => PopLayerState();
}

class PopLayerState extends State<PopLayer>
    with SingleTickerProviderStateMixin {
  final _pops = <Pop>[];
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  static const life = 1400;

  void add(Pop p) {
    _pops.add(p);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final now = DateTime.now().millisecondsSinceEpoch;
          _pops.removeWhere((p) => now - p.born > life);
          return LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              for (final p in _pops)
                Builder(builder: (context) {
                  final t = ((now - p.born) / life).clamp(0.0, 1.0);
                  final scale =
                      t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1.0;
                  final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
                  return Positioned(
                    left: p.at.dx * c.maxWidth - 150,
                    top: p.at.dy * c.maxHeight - 40 - t * 50,
                    width: 300,
                    height: 80,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Center(
                          child: Text(p.text,
                              textAlign: TextAlign.center,
                              style: Tv.title(p.size, color: p.color)
                                  .copyWith(shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black),
                                Shadow(
                                    blurRadius: 2,
                                    color: Colors.black,
                                    offset: Offset(0, 2)),
                              ])),
                        ),
                      ),
                    ),
                  );
                }),
            ]);
          });
        },
      ),
    );
  }
}

/// Bille brillante (snooker, billard, boules, pions).
void paintBall(Canvas c, Offset o, double r, Color color,
    {String? label,
    bool stripe = false,
    double alpha = 1,
    bool shadow = true}) {
  if (r <= 0.5) return;
  if (shadow) {
    c.drawOval(
        Rect.fromCenter(
            center: o + Offset(r * 0.18, r * 0.32),
            width: r * 2.1,
            height: r * 1.6),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25));
  }
  final base = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 1.0,
      colors: [
        Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: alpha),
        color.withValues(alpha: alpha),
        Color.lerp(color, Colors.black, 0.65)!.withValues(alpha: alpha),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: o, radius: r));
  if (stripe) {
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
    c.drawCircle(o, r,
        Paint()..color = const Color(0xFFF4F1E8).withValues(alpha: alpha));
    c.drawRect(Rect.fromCenter(center: o, width: r * 2, height: r * 1.1), base);
    // ombrage par-dessus le blanc
    c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45 * alpha)
            ],
            stops: const [0.5, 1],
          ).createShader(Rect.fromCircle(center: o, radius: r)));
    c.restore();
  } else {
    c.drawCircle(o, r, base);
  }
  if (label != null) {
    c.drawCircle(o, r * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha));
    final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                fontFamily: Tv.font,
                fontWeight: FontWeight.w900,
                fontSize: r * (label.length > 1 ? 0.62 : 0.75),
                color: const Color(0xFF151515).withValues(alpha: alpha))),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }
  // reflet
  c.drawOval(
      Rect.fromCenter(
          center: o + Offset(-r * 0.32, -r * 0.42),
          width: r * 0.7,
          height: r * 0.42),
      Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha));
}

/// Texte centré sur le canevas.
void paintText(Canvas c, String s, Offset o, double size, Color color,
    {FontWeight weight = FontWeight.w800,
    TextAlign align = TextAlign.center,
    double? maxWidth,
    bool shadow = false}) {
  final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: Tv.font,
              fontWeight: weight,
              fontSize: size,
              color: color,
              shadows: shadow
                  ? const [Shadow(blurRadius: 4, color: Colors.black)]
                  : null)),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…')
    ..layout(maxWidth: maxWidth ?? double.infinity);
  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => tp.width,
    _ => tp.width / 2,
  };
  tp.paint(c, o - Offset(dx, tp.height / 2));
}

/// Bandeau des joueurs en haut d'une scène : couleur, nom, score.
class ScoreStrip extends StatelessWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  final String Function(int)? sub;
  const ScoreStrip(
      {super.key, required this.game, required this.colorOf, this.sub});

  @override
  Widget build(BuildContext context) {
    final g = game;
    return Row(
      children: [
        for (var i = 0; i < g.players.length; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  colorOf(i).withValues(
                      alpha: i == g.current && !g.finished ? 0.75 : 0.35),
                  Colors.black.withValues(alpha: 0.55),
                ]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: i == g.current && !g.finished
                        ? Colors.white
                        : colorOf(i).withValues(alpha: 0.6),
                    width: i == g.current && !g.finished ? 1.6 : 1),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final roomy = c.maxWidth > 110;
                return Row(
                  children: [
                    if (roomy) ...[
                      PlayerAvatar(
                          id: g.players[i].id,
                          name: g.players[i].name,
                          color: colorOf(i),
                          size: 20),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(g.players[i].name.toUpperCase(),
                                maxLines: 1,
                                style: Tv.title(13, color: Colors.white)),
                          ),
                          if (sub != null)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(sub!(i),
                                  maxLines: 1,
                                  style: Tv.label(9, color: Colors.white70)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 3),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth * 0.45),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(g.scoreText(i),
                            style: Tv.title(18, color: Colors.white)),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Secousse (0 → 1) : décalage horizontal amorti.
Offset shake(double t, {double amp = 8}) {
  if (t <= 0 || t >= 1) return Offset.zero;
  final d = 1 - t;
  return Offset(sin(t * 40) * amp * d, cos(t * 33) * amp * 0.4 * d);
}

/// Particules d'une explosion (éclats, étincelles, pièces).
class Burst {
  final Offset at; // fraction de la scène
  final Color color;
  final int count;
  final double speed;
  final int seed;
  Burst(this.at, this.color, {this.count = 18, this.speed = 1, int? seed})
      : seed = seed ?? Random().nextInt(1 << 20);

  void paint(Canvas c, Size s, double t) {
    if (t <= 0 || t >= 1) return;
    final r = Random(seed);
    final o = Offset(at.dx * s.width, at.dy * s.height);
    for (var i = 0; i < count; i++) {
      final a = r.nextDouble() * 2 * pi;
      final v = (0.4 + r.nextDouble()) * speed * min(s.width, s.height) * 0.28;
      final p = o +
          Offset(cos(a), sin(a)) * v * Curves.easeOut.transform(t) +
          Offset(0, 60 * t * t);
      final sz = (2 + r.nextDouble() * 4) * (1 - t);
      c.drawCircle(p, sz,
          Paint()..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0)));
    }
  }
}
