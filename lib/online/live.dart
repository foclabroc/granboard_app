import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/darts_game.dart';
import '../players.dart';
import '../server.dart';
import '../ui/cricket_view.dart' show CricketStyle;
import '../ui/dartboard.dart' show PlayerBoards;

/// Partie à la maison envoyée au serveur pour être regardée en direct
/// (RPC `gb_live_push`, regardée par `gb_on_watch`). Envoi « le dernier
/// gagne », au plus une fois par [every] ; rien si aucun compte de ce
/// téléphone ne joue (que des invités / bots).
class LiveCast {
  LiveCast._();
  static final instance = LiveCast._();

  /// Délai mini entre deux envois (coupé dans les tests).
  @visibleForTesting
  static Duration every = const Duration(milliseconds: 1200);

  /// Coupe tout envoi (tests qui ne s'en occupent pas).
  static bool enabled = true;

  Map<String, dynamic>? _pending;
  PlayerProfile? _host;
  List<int> _players = const [];
  bool _sending = false;
  bool _ended = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _wait;
  Timer? _endTimer;

  /// Compte qui envoie : le 1er joueur de la partie qui est un compte de ce
  /// téléphone (session valable).
  static PlayerProfile? hostOf(DartsGame game) {
    final store = PlayerStore.instance;
    for (final p in game.players) {
      final acc = store.byId(p.id);
      if (acc != null && !acc.expired) return acc;
    }
    return null;
  }

  /// État de la partie (même format que pour l'écran TV, en plus léger).
  static Map<String, dynamic> stateOf(DartsGame game) {
    final store = PlayerStore.instance;
    return {
      'game': game.toJson(),
      'colors': {
        for (final p in game.players) p.id: store.colorOf(p.id).toARGB32(),
      },
      'boards': PlayerBoards.instance.all,
      'cricket': CricketStyle.current.value,
    };
  }

  /// Nouvel état de [game] à envoyer.
  void push(DartsGame game) {
    if (!enabled) return;
    final host = hostOf(game);
    if (host == null) return;
    _endTimer?.cancel();
    _ended = false;
    _host = host;
    _players = [
      for (final p in game.players)
        if (PlayerStore.instance.byId(p.id) != null) int.parse(p.id)
    ];
    _pending = stateOf(game);
    _kick();
  }

  /// Partie finie : l'état final reste visible [after], puis retiré.
  void end({Duration after = Duration.zero}) {
    if (!enabled || _host == null) return;
    _endTimer?.cancel();
    if (after > Duration.zero) {
      _endTimer = Timer(after, () => end());
      return;
    }
    _ended = true;
    _wait?.cancel();
    _pending = null;
    _kick();
  }

  void _kick() {
    if (_sending) return;
    final wait = every - DateTime.now().difference(_last);
    if (wait > Duration.zero && !_ended) {
      _wait ??= Timer(wait, () {
        _wait = null;
        _kick();
      });
      return;
    }
    _send();
  }

  Future<void> _send() async {
    final host = _host;
    if (host == null) return;
    _sending = true;
    try {
      while (true) {
        final st = _pending;
        final ended = _ended;
        if (st == null && !ended) break;
        _pending = null;
        _last = DateTime.now();
        try {
          await GbServer.rpc('gb_live_push', {
            'p_token': host.token,
            'p_state': ended ? null : st,
            'p_players': ended ? null : _players,
          });
        } catch (_) {
          // hors ligne : on garde l'état le plus récent pour plus tard
          if (!ended) _pending ??= st;
          break;
        }
        if (ended) {
          _ended = false;
          _host = null;
          break;
        }
        if (_pending != null) {
          _sending = false;
          _kick();
          return;
        }
      }
    } finally {
      _sending = false;
    }
  }
}
