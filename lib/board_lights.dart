import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/cricket.dart';
import 'game/darts_game.dart';
import 'game/match.dart';
import 'game/practice.dart';
import 'game/x01.dart';
import 'granboard.dart';

/// Lumières de la GranBoard 3s : contour (60 LED) et numéros.
///
/// Protocole relevé par keenanlk/granboard-ble-codes (non officiel, testé sur
/// une 3s) : commandes de 16 octets (type, couleur 1, couleur 2, position,
/// durée, persistant) et de 20 octets (un octet par numéro, 0x05 = orange).
/// La cible perd les commandes trop rapprochées : file d'attente, ~70 ms
/// entre deux envois, l'état (contour, numéros) remplace l'ancien en attente.
class BoardLights {
  BoardLights._();
  static final instance = BoardLights._();

  static const _prefOn = 'board_lights_v1';
  static const _prefNumbers = 'board_numbers_v1';
  static const gap = Duration(milliseconds: 70);

  /// Position de la LED du contour en face de chaque numéro (25 = bull).
  static const kLedPos = {
    25: 0, 1: 28, 2: 49, 3: 55, 4: 34, 5: 22, 6: 40, 7: 1, 8: 7, 9: 16, //
    10: 43, 11: 10, 12: 19, 13: 37, 14: 13, 15: 46, 16: 4, 17: 52, 18: 31,
    19: 58, 20: 25,
  };

  /// Contour, clignotements et vagues.
  bool enabled = true;

  /// Numéros à viser allumés (cibles du Cricket, prochaine fléchette en 01…).
  bool numbers = true;

  /// Envoi vers la cible (posé par [BoardService] quand une cible qui a une
  /// caractéristique d'écriture est connectée) ; null = rien à piloter.
  Future<void> Function(List<int> bytes)? writer;

  /// Commandes envoyées (tests).
  @visibleForTesting
  final sent = <List<int>>[];

  final _queue = <(String?, List<int>)>[];
  Timer? _timer;
  Color? _ring;
  List<int> _numbers = const [];

  /// Renvoi du contour et des numéros après le clignotement d'une touche :
  /// la cible efface ses lumières pendant son animation, les guides ne
  /// revenaient pas (envoyés seulement quand ils changent).
  Timer? _reassert;
  static const reassertDelay = Duration(milliseconds: 1500);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    enabled = p.getBool(_prefOn) ?? true;
    numbers = p.getBool(_prefNumbers) ?? true;
  }

  Future<void> setEnabled(bool on) async {
    enabled = on;
    (await SharedPreferences.getInstance()).setBool(_prefOn, on);
    if (!on && _active) _ringOff();
  }

  Future<void> setNumbers(bool on) async {
    numbers = on;
    (await SharedPreferences.getInstance()).setBool(_prefNumbers, on);
    if (!on && _active) _setNumbers(const []);
  }

  /// Cible connectée : on repart de zéro (son état est inconnu).
  void connected() {
    _ring = null;
    _numbers = const [];
    _send('numbers', List.filled(20, 0));
  }

  @visibleForTesting
  void debugReset() {
    _queue.clear();
    _timer?.cancel();
    _timer = null;
    sent.clear();
    _ring = null;
    _numbers = const [];
    writer = null;
  }

  // ─── Commandes ───

  static List<int> command(int type,
      {Color? a, Color? b, int pos = 0, int dur = 0x14, bool keep = false}) {
    int c(Color? x, double Function(Color) f) =>
        x == null ? 0 : (f(x) * 255).round().clamp(0, 255);
    return [
      type,
      c(a, (x) => x.r), c(a, (x) => x.g), c(a, (x) => x.b), //
      c(b, (x) => x.r), c(b, (x) => x.g), c(b, (x) => x.b),
      0, 0, 0, pos, 0, dur, 0, 0, keep ? 1 : 0,
    ];
  }

  void _send(String? key, List<int> bytes) {
    if (key != null) _queue.removeWhere((e) => e.$1 == key);
    _queue.add((key, bytes));
    if (_timer == null) {
      _timer = Timer.periodic(gap, (_) => _pump());
      _pump();
    }
  }

  void _pump() {
    if (_queue.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final (_, bytes) = _queue.removeAt(0);
    sent.add(bytes);
    if (sent.length > 200) sent.removeRange(0, 100);
    final w = writer;
    if (w != null) w(bytes).catchError((Object _) {});
  }

  bool get _active => writer != null;

  /// Contour allumé en continu d'une couleur.
  void _setRing(Color c) {
    if (_ring == c) return;
    _ring = c;
    _send('ring', command(0x14, a: c, keep: true));
  }

  void _ringOff() {
    _ring = null;
    _send('ring', command(0x14, keep: true));
  }

  void _setNumbers(List<int> list) {
    final l = [...list]..sort();
    if (listEquals(l, _numbers)) return;
    _numbers = l;
    _send('numbers', [
      for (var n = 1; n <= 20; n++) l.contains(n) ? 0x05 : 0,
    ]);
  }

  // ─── Jeu ───

  /// Fléchette lancée : la LED en face du numéro clignote (1 à 3 fois selon
  /// simple / double / triple, couleur du joueur), puis les effets : bust,
  /// 180, victoire.
  void dart(DartsGame game, DartHit? hit, Color color) {
    if (!_active) return;
    if (enabled && hit != null) {
      final pos = kLedPos[hit.number];
      if (pos != null) {
        _send(null, command(hit.multiplier.clamp(1, 3), a: color, pos: pos));
      }
    }
    final leg = game is MatchGame ? game.leg : game;
    if (enabled) {
      if (game.finished || (game is MatchGame && game.betweenLegs)) {
        _send(
            null,
            command(0x11,
                a: color, b: const Color(0xFFFFC400), pos: 0x10, dur: 0x05));
      } else if (leg is X01Game && leg.currentTurn.isBust) {
        _send(null, command(0x17, a: const Color(0xFFFF0000), dur: 0x1E));
      } else if (leg is X01Game &&
          leg.currentTurn.darts.length == 3 &&
          leg.currentTurn.total == 180) {
        _send(
            null,
            command(0x11,
                a: const Color(0xFFFFC400),
                b: const Color(0xFFFF0000),
                pos: 0x10,
                dur: 0x05));
      }
    }
    state(game, color);
    _reassert?.cancel();
    if (!enabled && !numbers) return;
    _reassert = Timer(reassertDelay, () {
      if (!_active) return;
      final ring = _ring, nums = _numbers;
      if (enabled && ring != null) {
        _ring = null;
        _setRing(ring);
      }
      if (numbers && nums.isNotEmpty) {
        _numbers = const [];
        _setNumbers(nums);
      }
    });
  }

  /// État continu : contour à la couleur du joueur en cours, numéros à viser
  /// (gardés allumés après les 3 fléchettes, jusqu'au joueur suivant).
  void state(DartsGame game, Color color) {
    if (!_active) return;
    if (enabled) {
      _setRing(color);
    }
    if (!numbers) return;
    final leg = game is MatchGame ? game.leg : game;
    if (game.finished) {
      _setNumbers(const []);
    } else if (!leg.turnOver) {
      _setNumbers(targetsOf(game));
    }
  }

  /// Essai depuis les réglages : vague, 20-19-18 allumés, puis tout s'éteint.
  void test() {
    _send(
        null,
        command(0x11,
            a: const Color(0xFFFFC400),
            b: const Color(0xFF00B0FF),
            pos: 0x10,
            dur: 0x05));
    _numbers = const [];
    _setNumbers(const [18, 19, 20]);
    _setRing(const Color(0xFF00E676));
    Timer(const Duration(seconds: 3), clear);
  }

  /// Fin de partie (page quittée) : tout s'éteint.
  void clear() {
    _reassert?.cancel();
    if (!_active) return;
    if (_ring != null) _ringOff();
    _setNumbers(const []);
  }

  /// Numéros à viser pour le joueur en cours (bull non adressable).
  static List<int> targetsOf(DartsGame game) {
    final g = game is MatchGame ? game.leg : game;
    if (g.turnOver) return const [];
    final out = <int>{};
    switch (g) {
      case X01Game x:
        final opts = x.checkoutOptions;
        if (opts.isNotEmpty && opts.first.isNotEmpty) {
          final n =
              int.tryParse(opts.first.first.replaceFirst(RegExp('^[DT]'), ''));
          if (n != null) out.add(n);
        } else {
          out.add(20); // pas de fin possible : le 20, comme d'habitude
        }
      case CricketGame c:
        final side = c.sideOf(c.current);
        for (var t = 0; t < c.targets.length; t++) {
          final tg = c.targets[t];
          if (!tg.revealed || c.dead(t) || c.closedBy(side, t)) continue;
          out.add(tg.number);
        }
      case PracticeGame p:
        for (final z in p.targetZones) {
          out.add(z.number);
        }
    }
    return [
      for (final n in out)
        if (n >= 1 && n <= 20) n
    ];
  }
}
