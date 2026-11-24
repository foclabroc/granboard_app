import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animation des cases des numéros (contour de la cible) quand aucune
/// fléchette n'est plantée : 12 styles au choix (Options › Animation du
/// contour), envoyés à l'écran TV.
///
/// [at] donne, pour la case `i` (0 = le 20, sens horaire) au temps `t` en
/// secondes (boucle de 6 s : `_spin` de la cible), l'intensité 0-1 et la
/// couleur (null = couleur du joueur en cours). Toutes les périodes divisent
/// 6 s : la boucle ne saute pas.
class RingAnim {
  final String id;
  final String name;
  final String help;
  final (double, Color?) Function(int i, double t) at;
  const RingAnim(this.id, this.name, this.help, this.at);

  static double _wrap(double x) => ((x % 20) + 20) % 20;

  /// Comète : tête en `head` (en cases), queue de `tail` cases.
  static double _comet(int i, double head, double tail, double max) {
    final b = _wrap(head - i);
    return b < tail ? max * (1 - b / tail) : 0;
  }

  static final classic = RingAnim(
      'classic',
      'Tranquille',
      'Une comète, queue de 3 cases, un tour en 3 s (l\'ancienne).',
      (i, t) => (_comet(i, t / 3 * 20, 3, 0.5), null));
  static final fast = RingAnim(
      'fast',
      'Rapide',
      'Une comète vive, un tour en 1,2 s.',
      (i, t) => (_comet(i, t / 1.2 * 20, 4, 0.85), null));
  static final turbo = RingAnim(
      'turbo', 'Turbo', 'Un tour en 0,75 s, longue traînée, tête blanche.',
      (i, t) {
    final b = _wrap(t / 0.75 * 20 - i);
    if (b < 1) return (1.0, Colors.white);
    return (b < 7 ? 0.9 * (1 - b / 7) : 0.0, null);
  });
  static final twin = RingAnim(
      'twin', 'Double comète', 'Deux comètes opposées, un tour en 1,5 s.',
      (i, t) {
    final h = t / 1.5 * 20;
    return (math.max(_comet(i, h, 4, 0.85), _comet(i, h + 10, 4, 0.85)), null);
  });
  static final chaser = RingAnim(
      'chaser',
      'Chenillard',
      'Façon fête foraine : une case sur 3, avance 10 fois par seconde.',
      (i, t) => ((i + (t * 10).floor()) % 3 == 0 ? 0.8 : 0.06, null));
  static final rush = RingAnim('rush', 'Accélération',
      'Démarre, file très vite puis freine, courte pause.', (i, t) {
    final p = (t % 2) / 1.6;
    if (p > 1) return (0.0, null);
    final k = p < .5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;
    return (_comet(i, k * 40, 5, 0.9), null);
  });
  static final pingPong = RingAnim('pingpong', 'Ping-pong',
      'Va-et-vient d\'un bout à l\'autre de l\'anneau.', (i, t) {
    final p = (t % 2) / 2;
    final x = (p < .5 ? p * 2 : 2 - p * 2) * 19;
    final d = (i - x).abs();
    return (d < 3 ? 0.9 * (1 - d / 3) : 0.0, null);
  });
  static final breath = RingAnim('breath', 'Respiration + éclair',
      'L\'anneau respire, une comète éclair passe toutes les 2 s.', (i, t) {
    final base = 0.12 + 0.1 * math.sin(t / 2 * 2 * math.pi);
    final p = (t % 2) / 0.5;
    return (p < 1 ? math.max(base, _comet(i, p * 20, 5, 1)) : base, null);
  });
  static final rainbow = RingAnim(
      'rainbow',
      'Arc-en-ciel',
      'Comète rapide (1 s) dont la couleur tourne avec elle.',
      (i, t) => (
            _comet(i, t * 20, 6, 0.9),
            HSVColor.fromAHSV(1, (t * 360 + i * 18) % 360, 0.85, 1).toColor()
          ));
  static final fill = RingAnim('fill', 'Remplissage',
      'Les cases s\'allument une à une, puis s\'éteignent ensemble.', (i, t) {
    final p = t % 1.5;
    if (p < 0.75) return (i < p / 0.75 * 20 ? 0.75 : 0.0, null);
    return (0.75 * math.max(0, 1 - (p - 0.75) / 0.4), null);
  });
  static final triple = RingAnim('triple', 'Triple comète',
      'Trois petites comètes à 120°, un tour en 2 s.', (i, t) {
    final h = t / 2 * 20;
    var e = 0.0;
    for (final o in [0.0, 20 / 3, 40 / 3]) {
      e = math.max(e, _comet(i, h + o, 3, 0.8));
    }
    return (e, null);
  });
  static final sparkle = RingAnim('sparkle', 'Étincelles',
      'Des cases au hasard s\'allument et s\'éteignent vite.', (i, t) {
    final s = (t * 8).floor();
    final r = math.sin((i * 91 + s * 37) * 12.9898) * 43758.5453;
    final v = r - r.floorToDouble();
    final ph = t * 8 - s;
    return (v > 0.72 ? (1 - ph) * 0.95 : 0.05, null);
  });

  static final all = [
    classic,
    fast,
    turbo,
    twin,
    chaser,
    rush,
    pingPong,
    breath,
    rainbow,
    fill,
    triple,
    sparkle,
  ];

  /// Par défaut : Rapide (l'ancienne était jugée trop lente).
  static RingAnim byId(String? id) =>
      all.firstWhere((a) => a.id == id, orElse: () => fast);

  static const _pref = 'ring_anim_v1';
  static final current = ValueNotifier<RingAnim>(fast);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      current.value = byId(p.getString(_pref));
    } catch (_) {}
  }

  static Future<void> choose(RingAnim a) async {
    current.value = a;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_pref, a.id);
    } catch (_) {}
  }
}
