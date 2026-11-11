// Moteur X01 (301 / 501 / 701 / 901) et Freeze 01.
//
// Pur Dart, sans Flutter : l'interface (téléphone aujourd'hui, TV plus tard)
// ne fait qu'envoyer des actions (fléchette, raté, joueur suivant, annuler)
// et lire l'état.
//
// L'état est recalculé en rejouant la liste des actions : « annuler » consiste
// simplement à retirer la dernière action, sans risque d'incohérence.

import '../granboard.dart';

enum InRule { open, double, master }

enum OutRule { open, double, master }

enum BullMode { split, fat }

const kStartScores = [301, 501, 701, 901];

extension InRuleLabel on InRule {
  String get label => switch (this) {
        InRule.open => 'Open In',
        InRule.double => 'Double In',
        InRule.master => 'Master In',
      };
}

extension OutRuleLabel on OutRule {
  String get label => switch (this) {
        OutRule.open => 'Open Out',
        OutRule.double => 'Double Out',
        OutRule.master => 'Master Out',
      };
}

extension BullModeLabel on BullMode {
  String get label => switch (this) {
        BullMode.split => 'Bull 25/50',
        BullMode.fat => 'Bull 50/50',
      };
}

class X01Settings {
  final int startScore;
  final InRule inRule;
  final OutRule outRule;
  final BullMode bullMode;

  /// Nombre de manches maximum (null = illimité). À la fin, le plus petit
  /// score restant gagne (total d'équipe en Freeze).
  final int? roundLimit;

  /// Freeze 01 : jeu en équipes, une équipe dont le total restant est
  /// supérieur à celui de l'adversaire est « gelée » et ne peut pas finir.
  final bool freeze;

  const X01Settings({
    this.startScore = 501,
    this.inRule = InRule.open,
    this.outRule = OutRule.double,
    this.bullMode = BullMode.split,
    this.roundLimit,
    this.freeze = false,
  });

  String get name => freeze ? 'Freeze $startScore' : '$startScore';

  Map<String, dynamic> toJson() => {
        'start': startScore,
        'in': inRule.index,
        'out': outRule.index,
        'bull': bullMode.index,
        if (roundLimit != null) 'rounds': roundLimit,
        'freeze': freeze,
      };

  factory X01Settings.fromJson(Map<String, dynamic> j) => X01Settings(
        startScore: (j['start'] as num?)?.toInt() ?? 501,
        inRule: InRule.values[(j['in'] as num?)?.toInt() ?? 0],
        outRule: OutRule.values[(j['out'] as num?)?.toInt() ?? 1],
        bullMode: BullMode.values[(j['bull'] as num?)?.toInt() ?? 0],
        roundLimit: (j['rounds'] as num?)?.toInt(),
        freeze: j['freeze'] as bool? ?? false,
      );

  String get rulesLabel => [
        inRule.label,
        outRule.label,
        bullMode.label,
        if (roundLimit != null) '$roundLimit manches',
      ].join(' · ');
}

class X01Player {
  final String id;
  final String name;

  /// Équipe (Freeze). En individuel, chaque joueur a sa propre équipe.
  final int team;

  const X01Player({required this.id, required this.name, this.team = 0});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'team': team};

  factory X01Player.fromJson(Map<String, dynamic> j) => X01Player(
        id: '${j['id']}',
        name: '${j['name']}',
        team: (j['team'] as num?)?.toInt() ?? 0,
      );
}

/// Une fléchette lancée : [hit] null = ratée (hors cible ou bouton « Raté »).
class ThrownDart {
  final DartHit? hit;

  /// Points réellement décomptés (0 si raté ou joueur pas encore ouvert).
  final int points;

  const ThrownDart(this.hit, this.points);

  String get label {
    final h = hit;
    if (h == null) return 'Raté';
    return h.label;
  }
}

enum BustReason { overshoot, leftOne, badFinish, frozen }

extension BustReasonLabel on BustReason {
  String get label => switch (this) {
        BustReason.overshoot => 'Score dépassé',
        BustReason.leftOne => 'Reste 1 : impossible à finir',
        BustReason.badFinish => 'Mauvaise fléchette de fin',
        BustReason.frozen => 'Équipe gelée : fin interdite',
      };
}

class Turn {
  final int player;
  final int round;
  final int scoreBefore;
  final bool openedBefore;
  final List<ThrownDart> darts = [];
  BustReason? bust;
  bool checkout = false;

  Turn(this.player, this.round, this.scoreBefore, this.openedBefore);

  bool get isBust => bust != null;

  /// Points marqués pendant la manche (0 si bust).
  int get total => isBust ? 0 : darts.fold(0, (s, d) => s + d.points);
}

class PlayerState {
  int remaining;
  bool opened;

  // Statistiques de la partie
  int darts = 0;
  int points = 0;
  int highestTurn = 0;
  int count180 = 0;
  int count100 = 0; // manches à 100 ou plus (180 compris)
  int? checkout;

  PlayerState(this.remaining, this.opened);

  /// Moyenne sur 3 fléchettes.
  double get average => darts == 0 ? 0 : points * 3 / darts;
}

enum EndReason { checkout, roundLimit }

sealed class _Action {
  const _Action();
}

class _DartAction extends _Action {
  final DartHit? hit;
  const _DartAction(this.hit);
}

class _NextAction extends _Action {
  const _NextAction();
}

class X01Game {
  final X01Settings settings;

  /// Joueurs dans l'ordre de lancer.
  final List<X01Player> players;

  final List<_Action> _actions = [];

  // État recalculé
  late List<PlayerState> _states;
  late List<Turn> _turns;
  int _current = 0;
  int _round = 1;
  List<int> _winners = [];
  EndReason? _endReason;

  X01Game(this.settings, this.players) {
    if (players.isEmpty) throw ArgumentError('Aucun joueur');
    if (settings.freeze) {
      final teams = players.map((p) => p.team).toSet();
      if (teams.length < 2) {
        throw ArgumentError('Le Freeze se joue avec au moins 2 équipes');
      }
    }
    _reset();
  }

  // ─── Lecture de l'état ───

  int get current => _current;
  X01Player get currentPlayer => players[_current];
  PlayerState get currentState => _states[_current];
  int get round => _round;
  List<Turn> get turns => List.unmodifiable(_turns);
  Turn get currentTurn => _turns.last;
  bool get finished => _endReason != null;
  EndReason? get endReason => _endReason;
  List<int> get winners => List.unmodifiable(_winners);
  bool get canUndo => _actions.isNotEmpty;

  /// Nombre d'actions jouées (fléchettes + « suivant »).
  int get actionCount => _actions.length;

  // ─── Sérialisation (écran TV, jeu à distance) ───
  // Actions : « n » = suivant, « m » = ratée, « d:<numéro>:<anneau> » = fléchette.

  List<String> get actionLog => [
        for (final a in _actions)
          switch (a) {
            _NextAction() => 'n',
            _DartAction(:final hit) =>
              hit == null ? 'm' : 'd:${hit.number}:${hit.ring.index}',
          }
      ];

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'players': [for (final p in players) p.toJson()],
        'actions': actionLog,
      };

  /// Rejoue une partie envoyée par [toJson] (actions invalides ignorées).
  factory X01Game.fromJson(Map<String, dynamic> j) {
    final g = X01Game(
      X01Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
      [
        for (final p in (j['players'] as List))
          X01Player.fromJson(Map<String, dynamic>.from(p as Map))
      ],
    );
    for (final a in (j['actions'] as List? ?? const [])) {
      g.applyLogEntry('$a');
    }
    return g;
  }

  /// Applique une action du journal ; renvoie false si elle est refusée.
  bool applyLogEntry(String a) {
    if (a == 'n') return next();
    if (a == 'm') return throwDart(null);
    final p = a.split(':');
    if (p.length != 3 || p[0] != 'd') return false;
    final n = int.tryParse(p[1]);
    final r = int.tryParse(p[2]);
    if (n == null || r == null || r < 0 || r >= Ring.values.length) {
      return false;
    }
    return throwDart(GranBoardDecoder.hitFor(n, Ring.values[r]));
  }

  PlayerState stateOf(int i) => _states[i];

  /// La manche du joueur est terminée (3 fléchettes, bust ou victoire) :
  /// on attend « joueur suivant ».
  bool get turnOver {
    final t = currentTurn;
    return finished || t.darts.length >= 3 || t.isBust || t.checkout;
  }

  int get dartsLeft => turnOver ? 0 : 3 - currentTurn.darts.length;

  List<int> get teams => players.map((p) => p.team).toSet().toList()..sort();

  List<int> membersOf(int team) => [
        for (var i = 0; i < players.length; i++)
          if (players[i].team == team) i
      ];

  int teamRemaining(int team) =>
      membersOf(team).fold(0, (s, i) => s + _states[i].remaining);

  /// Freeze : le joueur est gelé si le total de son équipe est supérieur
  /// au plus petit total des équipes adverses.
  bool isFrozen(int player) {
    if (!settings.freeze) return false;
    final team = players[player].team;
    final mine = teamRemaining(team);
    final others = teams.where((t) => t != team).map(teamRemaining);
    return mine > others.reduce((a, b) => a < b ? a : b);
  }

  /// Dernière manche jouée par le joueur (null s'il n'a pas encore joué).
  Turn? lastTurnOf(int player) {
    for (var i = _turns.length - 1; i >= 0; i--) {
      final t = _turns[i];
      if (t.player == player && (t != currentTurn || turnOver)) return t;
    }
    return null;
  }

  /// Suggestion de fin pour le joueur en cours (null si aucune).
  List<String>? get checkoutHint {
    if (finished || turnOver) return null;
    final s = currentState;
    if (!s.opened || isFrozen(_current)) return null;
    return suggestCheckout(
        s.remaining, dartsLeft, settings.outRule, settings.bullMode);
  }

  // ─── Actions ───

  /// Fléchette détectée par la cible ([hit] null = ratée).
  /// Renvoie false si elle est ignorée (manche déjà terminée).
  bool throwDart(DartHit? hit) => _push(_DartAction(hit));

  /// Joueur suivant (bouton de la cible ou de l'écran). Les fléchettes
  /// non lancées de la manche comptent comme ratées.
  bool next() => _push(const _NextAction());

  bool undo() {
    if (_actions.isEmpty) return false;
    _actions.removeLast();
    _reset();
    for (final a in _actions) {
      _apply(a);
    }
    return true;
  }

  bool _push(_Action a) {
    if (!_apply(a)) return false;
    _actions.add(a);
    return true;
  }

  void _reset() {
    final opened = settings.inRule == InRule.open;
    _states = [
      for (final _ in players) PlayerState(settings.startScore, opened)
    ];
    _current = 0;
    _round = 1;
    _winners = [];
    _endReason = null;
    _turns = [Turn(0, 1, settings.startScore, opened)];
  }

  bool _apply(_Action a) => switch (a) {
        _DartAction(:final hit) => _applyDart(hit),
        _NextAction() => _applyNext(),
      };

  bool _applyDart(DartHit? hit) {
    if (turnOver) return false;
    final s = currentState;
    final t = currentTurn;

    final value = _value(hit, settings.bullMode);
    final isDouble = _isDoubleLike(hit, settings.bullMode);
    final isMaster = _isMasterLike(hit, settings.bullMode);

    var counted = value;
    if (!s.opened) {
      final opens = switch (settings.inRule) {
        InRule.open => true,
        InRule.double => isDouble,
        InRule.master => isMaster,
      };
      if (opens) {
        s.opened = true;
      } else {
        counted = 0;
      }
    }

    final frozen = isFrozen(_current); // avant la fléchette
    t.darts.add(ThrownDart(hit, counted));
    s.darts++;
    s.points += counted;

    final left = s.remaining - counted;
    BustReason? bust;
    var finish = false;

    if (left < 0) {
      bust = BustReason.overshoot;
    } else if (left == 0) {
      final okFinish = switch (settings.outRule) {
        OutRule.open => true,
        OutRule.double => isDouble,
        OutRule.master => isMaster,
      };
      if (!okFinish) {
        bust = BustReason.badFinish;
      } else if (frozen) {
        bust = BustReason.frozen;
      } else {
        finish = true;
      }
    } else if (left == 1 && settings.outRule != OutRule.open) {
      bust = BustReason.leftOne;
    }

    if (bust != null) {
      // Retour au score du début de manche, les points de la manche sont perdus
      s.points -= t.darts.fold<int>(0, (sum, d) => sum + d.points);
      s.remaining = t.scoreBefore;
      s.opened = t.openedBefore;
      t.bust = bust;
      return true;
    }

    s.remaining = left;
    if (finish) {
      t.checkout = true;
      s.checkout = t.total;
      _closeTurnStats(t);
      _winners = settings.freeze ? membersOf(currentPlayer.team) : [_current];
      _endReason = EndReason.checkout;
    } else if (t.darts.length >= 3) {
      _closeTurnStats(t);
    }
    return true;
  }

  bool _applyNext() {
    if (finished) return false;
    final t = currentTurn;
    final s = currentState;
    if (!turnOver) {
      // Fléchettes non lancées = ratées
      final missing = 3 - t.darts.length;
      for (var i = 0; i < missing; i++) {
        t.darts.add(const ThrownDart(null, 0));
      }
      s.darts += missing;
      _closeTurnStats(t);
    } else if (t.isBust) {
      // Les fléchettes non lancées après un bust comptent dans la moyenne
      s.darts += 3 - t.darts.length;
    }

    _current = (_current + 1) % players.length;
    if (_current == 0) _round++;

    final limit = settings.roundLimit;
    if (limit != null && _round > limit) {
      _round = limit;
      _current = (_current - 1 + players.length) % players.length;
      _endByLimit();
      return true;
    }

    final n = currentState;
    _turns.add(Turn(_current, _round, n.remaining, n.opened));
    return true;
  }

  void _closeTurnStats(Turn t) {
    final s = _states[t.player];
    final total = t.total;
    if (total > s.highestTurn) s.highestTurn = total;
    if (total >= 100) s.count100++;
    if (total == 180) s.count180++;
  }

  void _endByLimit() {
    if (settings.freeze) {
      final scores = {for (final t in teams) t: teamRemaining(t)};
      final best = scores.values.reduce((a, b) => a < b ? a : b);
      _winners = [
        for (final t in teams)
          if (scores[t] == best) ...membersOf(t)
      ];
    } else {
      final best =
          _states.map((s) => s.remaining).reduce((a, b) => a < b ? a : b);
      _winners = [
        for (var i = 0; i < players.length; i++)
          if (_states[i].remaining == best) i
      ];
    }
    _endReason = EndReason.roundLimit;
  }
}

// ─── Valeur des fléchettes selon le mode de bull ───

int _value(DartHit? h, BullMode bull) {
  if (h == null) return 0;
  if (h.isBull && bull == BullMode.fat) return 50;
  return h.score;
}

bool _isDoubleLike(DartHit? h, BullMode bull) {
  if (h == null) return false;
  if (h.isBull && bull == BullMode.fat) return true;
  return h.isDouble;
}

bool _isMasterLike(DartHit? h, BullMode bull) {
  if (h == null) return false;
  return h.isBull || h.multiplier >= 2;
}

// ─── Suggestion de fin ───

class _Dart {
  final String label;
  final int value;
  final bool isDouble;
  final bool isMaster;
  const _Dart(this.label, this.value, this.isDouble, this.isMaster);
}

List<_Dart> _setupDarts(BullMode bull) => [
      for (var n = 20; n >= 1; n--) _Dart('T$n', n * 3, false, true),
      for (var n = 20; n >= 1; n--) _Dart('$n', n, false, false),
      if (bull == BullMode.split) const _Dart('25', 25, false, true),
      const _Dart('BULL', 50, true, true),
    ];

const _preferredDoubles = [
  20,
  16,
  18,
  12,
  10,
  8,
  14,
  6,
  4,
  2,
  19,
  17,
  15,
  13,
  11,
  9,
  7,
  5,
  3,
  1
];

List<_Dart> _finishDarts(OutRule out, BullMode bull) {
  final doubles = [
    for (final n in _preferredDoubles) _Dart('D$n', n * 2, true, true),
    const _Dart('BULL', 50, true, true),
  ];
  return switch (out) {
    OutRule.double => doubles,
    OutRule.master => [
        ...doubles,
        for (var n = 20; n >= 1; n--) _Dart('T$n', n * 3, false, true),
        if (bull == BullMode.split) const _Dart('25', 25, false, true),
      ],
    OutRule.open => [
        for (var n = 20; n >= 1; n--) _Dart('$n', n, false, false),
        if (bull == BullMode.split) const _Dart('25', 25, false, true),
        ...doubles,
        for (var n = 20; n >= 1; n--) _Dart('T$n', n * 3, false, true),
      ],
  };
}

/// Combinaison de fin en [dartsLeft] fléchettes au plus, ou null.
List<String>? suggestCheckout(
    int remaining, int dartsLeft, OutRule out, BullMode bull) {
  if (remaining <= 0 || dartsLeft <= 0 || remaining > 180) return null;
  final setup = _setupDarts(bull);
  final finish = _finishDarts(out, bull);
  final minLeft = out == OutRule.open ? 1 : 2;

  List<String>? search(int rem, int darts) {
    if (darts == 1) {
      for (final d in finish) {
        if (d.value == rem) return [d.label];
      }
      return null;
    }
    for (final d in setup) {
      final left = rem - d.value;
      if (left < minLeft) continue;
      final rest = search(left, darts - 1);
      if (rest != null) return [d.label, ...rest];
    }
    return null;
  }

  for (var n = 1; n <= dartsLeft; n++) {
    final r = search(remaining, n);
    if (r != null) return r;
  }
  return null;
}
