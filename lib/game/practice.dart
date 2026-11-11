// Jeux d'entraînement (GranDarts) : Count Up, Target 20 / Bull / Choix de
// cible / Hat / Horse, Half It, Delta Shoot, Rotation, Shoot Force, Oniren,
// CR Count Up, CR Multiple, Bob's 27, Finition 121, Spider, Pirates.
//
// Un seul moteur (PracticeGame) gère les tours, les manches, l'annulation et
// le rejeu ; chaque jeu fournit ses règles (PracticeRules). Pur Dart, même
// journal d'actions que les autres jeux, plus « c:<numéro> » (changer de
// cible, Choix de cible). Tirages au hasard tirés d'une graine : téléphone et
// TV obtiennent les mêmes cibles.

import 'dart:math';

import '../granboard.dart';
import 'darts_game.dart';
import 'x01.dart' show BullMode, X01Player;

enum PracticeKind {
  countUp,
  target20,
  targetBull,
  targetChoice,
  targetHat,
  targetHorse,
  halfIt,
  deltaShoot,
  rotation,
  shootForce,
  oniren,
  crCountUp,
  crMultiple,
  bobs27,
  checkout121,
  spider,
  pirates,
  // Fête
  funMission,
  allFives,
  beyondTop,
  kickDown,
  twoLine,
  shanghai,
  hyperBull,
  hideAndSeek,
  killer,
  treasureHunt,
  ticTacToe,
  baseball,
  golf,
  scram,
  football,
  hotPotato,
}

/// Réglages proposés pour chaque jeu.
class PracticeInfo {
  final String name;
  final String help;

  /// Choix de manches (null = pas de choix).
  final List<int>? rounds;
  final int? defaultRounds;

  /// Objectifs (touches, hat tricks…) ; 0 = « en 10 manches ».
  final List<int>? goals;
  final int? defaultGoal;

  /// Cible au choix (Choix de cible, Target Hat).
  final bool target;

  /// Options (clé → libellé).
  final Map<String, String> options;
  final bool bull;

  /// Jeu de fête (onglet FÊTE) plutôt qu'entraînement.
  final bool party;
  final int minPlayers;
  final int maxPlayers;
  const PracticeInfo(this.name, this.help,
      {this.rounds,
      this.defaultRounds,
      this.goals,
      this.defaultGoal,
      this.target = false,
      this.options = const {},
      this.bull = false,
      this.party = false,
      this.minPlayers = 1,
      this.maxPlayers = 8});
}

/// Grille affichée à la place de la cible (Two Line, Morpion, Cache-cache).
class PracticeCell {
  final String label;
  final int? owner;
  final bool star;
  final bool open;
  final String? sub;
  const PracticeCell(this.label,
      {this.owner, this.star = false, this.open = false, this.sub});
}

class PracticeGrid {
  final int cols;
  final List<PracticeCell> cells;
  const PracticeGrid(this.cols, this.cells);
}

const kPracticeInfo = <PracticeKind, PracticeInfo>{
  PracticeKind.countUp: PracticeInfo('Count Up',
      'Chaque fléchette rapporte sa valeur : le plus gros total gagne. 33 manches = défi des 99 fléchettes.',
      rounds: [1, 2, 3, 4, 5, 6, 7, 8, 10, 15, 33],
      defaultRounds: 8,
      bull: true),
  PracticeKind.target20: PracticeInfo('Target 20',
      'Vise le 20 : simple = 1 touche, double = 2, triple = 3. Le premier à l\'objectif gagne (ou le plus de touches en 10 manches).',
      goals: [5, 10, 30, 50, 100, 0], defaultGoal: 10),
  PracticeKind.targetBull: PracticeInfo('Target Bull',
      'Vise le bull : 25 = 1 touche, 50 = 2. Le premier à l\'objectif gagne (ou le plus de touches en 10 manches).',
      goals: [5, 10, 30, 50, 100, 0], defaultGoal: 10),
  PracticeKind.targetChoice: PracticeInfo('Choix de cible',
      'Choisis ta cible (et changes-en quand tu veux, avant ta 1re fléchette) : simple = 1 touche, double = 2, triple = 3.',
      goals: [5, 10, 30, 50, 100], defaultGoal: 10, target: true),
  PracticeKind.targetHat: PracticeInfo('Target Hat',
      'Hat trick : tes 3 fléchettes de la manche dans la cible choisie. Le premier à l\'objectif gagne.',
      goals: [5, 10, 30, 50, 100], defaultGoal: 5, target: true),
  PracticeKind.targetHorse: PracticeInfo('Target Horse',
      'White Horse : 3 triples sur 3 numéros différents du Cricket (15 à 20) dans la même manche.',
      goals: [5, 10, 15, 20, 25, 30], defaultGoal: 5),
  PracticeKind.halfIt: PracticeInfo('Half It',
      'Départ à 40. 9 manches : 15, 16, doubles, 17, 18, triples, 19, 20, bull. Aucune touche dans la manche = score divisé par 2.'),
  PracticeKind.deltaShoot: PracticeInfo('Delta Shoot',
      '16 manches : 10, 11, 12, double ou triple, 13, 14, double, 15, 16, 17, triple, 18, 19, 20, bull, double bull. Aucune touche = score ÷ 2.'),
  PracticeKind.rotation: PracticeInfo('Rotation',
      'Touche le 1, puis le 2… jusqu\'au 20, puis 3 bulls. Chaque cible rapporte son numéro ; touche à la 3e fléchette = 3 fléchettes de plus. Fini en moins de 8 manches = bonus.',
      options: {'double': 'Doubles seulement', 'triple': 'Triples seulement'}),
  PracticeKind.shootForce: PracticeInfo('Shoot Force',
      '1 à 20 puis le bull : chaque touche vaut sa valeur × ta série de touches. 3 triples dans la manche = +3000, simple bull 10 000, double bull 100 000. 8 manches.'),
  PracticeKind.oniren: PracticeInfo('Oniren',
      'Une cible au hasard par manche : 2 simples + 1 double ou triple dessus pour la valider. Manche ratée = une vie en moins (3 vies).'),
  PracticeKind.crCountUp: PracticeInfo('CR Count Up',
      '20, 19, 18, 17, 16, 15, bull, puis au choix 15, 20 ou bull. Points = valeur × marques.'),
  PracticeKind.crMultiple: PracticeInfo('CR Multiple',
      '20 à 15 puis bull : 1re fléchette ×1, 2e ×2, 3e ×3. Manches 4 et 7 : 3 numéros bonus (×2 ×4 ×6 puis ×3 ×6 ×9). Rien touché = -3 × la cible.'),
  PracticeKind.bobs27: PracticeInfo('Bob\'s 27',
      'Départ à 27. D1 à D20 puis double bull, 3 fléchettes chacun : + valeur du double à chaque touche, - sa valeur si aucune.',
      options: {
        'hard': 'Hard (éliminé à 0)',
        'even': 'Doubles pairs seulement'
      }),
  PracticeKind.checkout121: PracticeInfo('Finition 121',
      'Finis 121 en Double Out avec 9 fléchettes : réussi = cible +1, raté = cible -1. Le premier à finir 125 gagne (sinon la plus haute cible en 30 manches).',
      rounds: [3, 6, 9, 12, 15, 18], defaultRounds: 9),
  PracticeKind.spider: PracticeInfo('Spider',
      'Abats des araignées : ramène leur nombre à 0 pile (dépasser = rien). Bonus : manche sans raté ×2, fin sur double/triple ×2, les 8 araignées = 500 par manche restante. 15 manches.'),
  PracticeKind.pirates: PracticeInfo('Pirates',
      'Bull seulement (25 / 50) : un navire coule tous les 200 points. Après 3 navires, chance au trésor (bulls bonus) puis bonus de vitesse. 15 manches.',
      options: {
        'kids': 'Kids (12 manches, tout bull = 50)',
        'master': 'Master (50 seulement)'
      }),
  // ─── Fête ───
  PracticeKind.funMission: PracticeInfo('Fun Mission',
      'Une mission par manche (un triple, 60 points, le bull…). À 2 : mission réussie = tu prends 1 vie à l\'adversaire (4 vies chacun), il faut toutes les prendre. Seul : réussie +1, ratée -1, atteins 8.',
      party: true, maxPlayers: 2),
  PracticeKind.allFives: PracticeInfo('All Fives',
      'Si le total de tes 3 fléchettes est un multiple de 5, tu marques total ÷ 5. Atteins l\'objectif pile (dépasser = 0).',
      goals: [51, 61, 71],
      defaultGoal: 51,
      party: true,
      options: {
        'nodt': 'Doubles / triples valent 0',
        'miss': 'Points même avec une fléchette ratée'
      }),
  PracticeKind.beyondTop: PracticeInfo('Beyond Top',
      'Fais plus que le joueur d\'avant (30 au départ) : 1 point par tranche de 10 au-dessus. Sinon une vie en moins (6 vies). 10 manches, ou le dernier survivant.',
      party: true, minPlayers: 2),
  PracticeKind.kickDown: PracticeInfo('Kick Down',
      'Course de 0 à 301 (ou 501) pile. Tomber sur le score d\'un adversaire le renvoie à 0 ! Dépasser = OVER SCORE : tu perds des points.',
      goals: [301, 501],
      defaultGoal: 301,
      party: true,
      minPlayers: 2,
      bull: true,
      options: {
        'double': 'Finir sur un double',
        'p150': 'Pénalité -150 (sinon -100)',
        'prand': 'Pénalité au hasard'
      }),
  PracticeKind.twoLine: PracticeInfo('Two Line',
      'Bingo 5 × 5 : touche un numéro pour le prendre, touche les tiens pour marquer. Reprendre un numéro adverse : 2 simples ou 1 double le libèrent, 1 triple le prend. 2 lignes + plus de points = victoire. 2 bulls dans la manche = numéros mélangés.',
      party: true, minPlayers: 2, maxPlayers: 2),
  PracticeKind.shanghai: PracticeInfo('Shanghai',
      'Manche 1 = le 1, manche 2 = le 2… Points = numéro × 1, 2 ou 3. Simple + double + triple dans la manche = SHANGHAI, victoire immédiate.',
      rounds: [7, 10, 20],
      defaultRounds: 7,
      party: true,
      options: {
        'infinity': 'Infinity (Shanghai = numéro × 10, on continue)',
        'half': 'Rien touché = score ÷ 2'
      }),
  PracticeKind.hyperBull: PracticeInfo('Hyper Bull',
      'Tout l\'intérieur de l\'anneau des triples vaut 50, le bull 75, le centre 100 ; le reste compte normalement. 8 manches (2400 au maximum).',
      party: true),
  PracticeKind.hideAndSeek: PracticeInfo('Cache-cache',
      '12 fenêtres numérotées cachent 6 animaux gentils et 1 méchant. Ouvre une fenêtre en touchant son numéro (simple 20, double 100, triple 150). 3 animaux dans la manche = +200, aucun = -100, aucun numéro = ÷ 2. Un bull cache un méchant de plus. 10 manches.',
      party: true, minPlayers: 2),
  PracticeKind.killer: PracticeInfo('Killer',
      'Chacun a son numéro. Touche le tien pour gagner des vies (3 = KILLER), puis ceux des autres pour leur en retirer. À 0 vie, une touche de plus élimine. Le dernier en vie gagne.',
      party: true,
      minPlayers: 2,
      options: {
        'double': 'Doubles seulement',
        'triple': 'Triples seulement',
        'onehit': 'Killer en une touche'
      }),
  PracticeKind.treasureHunt: PracticeInfo('Treasure Hunt',
      'Chaque numéro touché cache un trésor (coffre, diamant, lingot ×2, bouclier, couteau et épée pour voler) ou un piège (crânes, grenade ; bull = crâne, tour passé). Manches 3, 6, 9 : trésors ×2 ; 4, 7, 10 : effets inversés. 10 manches.',
      party: true, maxPlayers: 4),
  PracticeKind.ticTacToe: PracticeInfo('Morpion',
      'Grille de numéros : 4 marques pour prendre une case (simple 1, double 2, triple 3). Aligne tes cases pour gagner ; toucher tes cases rapporte des points.',
      party: true,
      maxPlayers: 2,
      options: {
        'mark8': '8 marques par case',
        'big': 'Grille 4 × 4 (4 alignées)'
      }),
  PracticeKind.baseball: PracticeInfo('Baseball',
      '9 manches : manche 1 = le 1… Simple = 1 point, double = 2, triple = 3. Égalité = manches en plus (12 au plus).',
      party: true),
  PracticeKind.golf: PracticeInfo('Golf',
      'Trou 1 = le 1, trou 2 = le 2… Ta meilleure fléchette compte : triple = 1 coup, double = 2, simple = 3, rien = 5. Le plus petit total gagne.',
      rounds: [9, 18], defaultRounds: 9, party: true),
  PracticeKind.scram: PracticeInfo('Scram',
      '20 à 15 et bull. 1re partie : A ferme (une touche suffit), B marque des points sur ce qui reste ouvert. 2e partie : on échange. Le meilleur total gagne.',
      party: true, minPlayers: 2, maxPlayers: 2),
  PracticeKind.football: PracticeInfo('Football',
      'Touche le bull pour avoir le ballon. Avec le ballon, chaque double = un but ; une manche sans double rend le ballon. Un bull de l\'adversaire le lui donne. Le premier à 5 buts gagne.',
      goals: [3, 5, 10], defaultGoal: 5, party: true, minPlayers: 2),
  PracticeKind.hotPotato: PracticeInfo('Patate chaude',
      'Une bombe sur un numéro, avec une mèche de 3 à 6 fléchettes. Touche son numéro pour la passer au suivant. Si la mèche s\'éteint dans tes mains : une vie en moins (3 vies). Le dernier survivant gagne.',
      party: true, minPlayers: 2),
};

class PracticeSettings {
  final PracticeKind kind;
  final int? rounds;
  final int? goal;
  final int target;
  final BullMode bull;
  final Set<String> options;
  final int seed;
  const PracticeSettings(this.kind,
      {this.rounds,
      this.goal,
      this.target = 20,
      this.bull = BullMode.split,
      this.options = const {},
      this.seed = 0});

  PracticeInfo get info => kPracticeInfo[kind]!;
  String get name => info.name;
  int get goalOrDefault => goal ?? info.defaultGoal ?? 0;
  int get roundsOrDefault => rounds ?? info.defaultRounds ?? 0;
  bool has(String o) => options.contains(o);

  PracticeSettings withSeed(int s) => PracticeSettings(kind,
      rounds: rounds,
      goal: goal,
      target: target,
      bull: bull,
      options: options,
      seed: s);

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        if (rounds != null) 'rounds': rounds,
        if (goal != null) 'goal': goal,
        'target': target,
        'bull': bull.index,
        'opt': options.toList(),
        'seed': seed,
      };

  factory PracticeSettings.fromJson(Map<String, dynamic> j) => PracticeSettings(
        PracticeKind.values.firstWhere((k) => k.name == j['k'],
            orElse: () => PracticeKind.countUp),
        rounds: (j['rounds'] as num?)?.toInt(),
        goal: (j['goal'] as num?)?.toInt(),
        target: (j['target'] as num?)?.toInt() ?? 20,
        bull: BullMode.values[(j['bull'] as num?)?.toInt() ?? 0],
        options: {for (final o in (j['opt'] as List? ?? const [])) '$o'},
        seed: (j['seed'] as num?)?.toInt() ?? 0,
      );
}

/// Une fléchette : points gagnés (ou perdus) et si elle a servi.
class PracticeDart {
  final DartHit? hit;
  int points;
  bool ok;
  PracticeDart(this.hit, {this.points = 0, this.ok = false});
}

class PracticeTurn {
  final int player;
  final int round;
  final List<PracticeDart> darts = [];
  int maxDarts = 3;

  /// Cible au début de la manche (affichage, historique).
  final String target;
  final int scoreBefore;

  /// Effet de fin de manche (« ÷ 2 », « -10 », « VALIDÉ »…).
  String? note;
  PracticeTurn(this.player, this.round, this.target, this.scoreBefore);

  int get points => darts.fold(0, (s, d) => s + d.points);
  int get okCount => darts.where((d) => d.ok).length;
}

class PracticePlayer {
  int score = 0;
  int hits = 0; // touches / hats / horses / navires… selon le jeu
  int lives = 3;
  bool out = false; // éliminé
  bool done = false; // a fini
  int step = 0; // position dans la suite de cibles
  int streak = 0;
  int darts = 0;
  int good = 0; // fléchettes utiles
  int? doneRound;
  final Map<String, int> v = {};
}

enum PracticeEnd { goal, limit, allOut }

class PracticeGame implements DartsGame {
  final PracticeSettings settings;
  @override
  final List<X01Player> players;
  late final PracticeRules rules = PracticeRules.of(settings);

  final List<String> _log = [];
  late List<PracticePlayer> _st;

  /// État commun à la partie (grilles, fenêtres…), pour les règles.
  final Map<String, dynamic> shared = {};
  late List<PracticeTurn> _turns;
  int _current = 0;
  int _round = 1;
  List<int> _winners = [];
  PracticeEnd? _end;

  PracticeGame(this.settings, this.players) {
    if (players.isEmpty) throw ArgumentError('Aucun joueur');
    _reset();
  }

  factory PracticeGame.fromJson(Map<String, dynamic> j) {
    final g = PracticeGame(
      PracticeSettings.fromJson(
          Map<String, dynamic>.from(j['settings'] as Map)),
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

  // ─── Lecture ───

  PracticePlayer stateOf(int i) => _st[i];
  PracticeTurn get currentTurn => _turns.last;
  List<PracticeTurn> get turns => List.unmodifiable(_turns);
  PracticeEnd? get endReason => _end;
  int get roundCount => _round;

  /// Classement (meilleur d'abord).
  List<int> get ranking {
    final r = List.generate(players.length, (i) => i);
    r.sort((a, b) {
      final w = (_winners.contains(a) ? 0 : 1) - (_winners.contains(b) ? 0 : 1);
      if (w != 0) return w;
      return rules.compare(this, a, b);
    });
    return r;
  }

  /// Texte de la cible du joueur en cours.
  String get targetLabel => rules.target(this, _current);

  /// Zones à mettre en valeur sur la cible.
  List<DartHit> get targetZones => rules.zones(this, _current);

  /// Infos du joueur (vies, série, navires…).
  String infoOf(int p) => rules.info(this, p);

  /// Score affiché du joueur.
  String scoreText(int p) => rules.scoreText(this, p);

  // ─── Interface commune ───

  @override
  String get kind => 'practice';
  @override
  String get title => settings.name;
  @override
  String get rulesLabel => rules.rulesLabel(this);
  @override
  int get current => _current;
  @override
  X01Player get currentPlayer => players[_current];
  @override
  int get round => _round;
  @override
  int? get roundLimit => rules.roundLimit(this);
  @override
  bool get finished => _end != null;
  @override
  bool get turnOver {
    if (finished) return true;
    final t = currentTurn;
    final s = _st[_current];
    return t.darts.length >= t.maxDarts || s.done || s.out;
  }

  @override
  bool get canUndo => _log.isNotEmpty;
  @override
  List<int> get winners => List.unmodifiable(_winners);
  @override
  List<DartHit?> get turnHits => [for (final d in currentTurn.darts) d.hit];
  @override
  List<String> get actionLog => List.unmodifiable(_log);

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'settings': settings.toJson(),
        'players': [for (final p in players) p.toJson()],
        'actions': actionLog,
      };

  @override
  bool applyLogEntry(String a) {
    if (a.startsWith('c:')) {
      final n = int.tryParse(a.substring(2));
      return n != null && changeTarget(n);
    }
    final e = parseLogEntry(a);
    if (e == null) return false;
    return e.$1 ? next() : throwDart(e.$2);
  }

  /// Choix de cible : nouvelle cible (1-20 ou 25), avant la 1re fléchette.
  bool get canChangeTarget =>
      settings.info.target &&
      !finished &&
      currentTurn.darts.isEmpty &&
      settings.kind == PracticeKind.targetChoice;

  bool changeTarget(int n) {
    if (!canChangeTarget || !((n >= 1 && n <= 20) || n == 25)) return false;
    _st[_current].v['t'] = n;
    _log.add('c:$n');
    _turns.last = PracticeTurn(
        _current, _round, rules.target(this, _current), _st[_current].score);
    return true;
  }

  @override
  bool throwDart(DartHit? hit) {
    if (turnOver) return false;
    final t = currentTurn;
    final s = _st[_current];
    final d = PracticeDart(hit);
    t.darts.add(d);
    s.darts++;
    rules.onDart(this, _current, t, d);
    if (d.ok) s.good++;
    _log.add(logEntryOf(false, hit));
    _checkEnd(afterDart: true);
    return true;
  }

  @override
  bool next() {
    if (finished) return false;
    final t = currentTurn;
    final s = _st[_current];
    // Fléchettes non lancées = ratées (si le joueur joue encore)
    while (t.darts.length < t.maxDarts && !s.done && !s.out) {
      final d = PracticeDart(null);
      t.darts.add(d);
      s.darts++;
      rules.onDart(this, _current, t, d);
    }
    rules.onTurnEnd(this, _current, t);
    _log.add('n');
    _checkEnd(afterDart: false);
    if (finished) return true;

    // Joueur suivant encore en jeu
    final n = players.length;
    var i = _current;
    for (var k = 0; k < n; k++) {
      i = (i + 1) % n;
      if (i == 0) _round++;
      if (!_st[i].done && !_st[i].out && !rules.skipTurn(this, i)) break;
    }
    _current = i;
    final limit = roundLimit;
    if (limit != null && _round > limit) {
      _round = limit;
      _finish(PracticeEnd.limit);
      return true;
    }
    rules.onTurnStart(this, _current);
    _turns.add(PracticeTurn(
        _current, _round, rules.target(this, _current), _st[_current].score));
    return true;
  }

  @override
  bool undo() {
    if (_log.isEmpty) return false;
    final log = [..._log]..removeLast();
    _log.clear();
    _reset();
    for (final a in log) {
      applyLogEntry(a);
    }
    return true;
  }

  // ─── Fonctionnement ───

  void _reset() {
    shared.clear();
    _st = [for (final _ in players) PracticePlayer()];
    for (var i = 0; i < players.length; i++) {
      rules.init(this, i, _st[i]);
    }
    _current = 0;
    _round = 1;
    _winners = [];
    _end = null;
    _turns = [];
    rules.onTurnStart(this, 0);
    _turns.add(PracticeTurn(0, 1, rules.target(this, 0), _st[0].score));
  }

  void _checkEnd({required bool afterDart}) {
    if (finished) return;
    final s = _st[_current];
    if (s.done) s.doneRound ??= _round;
    // Objectif atteint : la partie s'arrête (le premier gagne)
    if (rules.goalEndsGame && s.done) {
      _finish(PracticeEnd.goal);
      return;
    }
    if (_st.every((x) => x.done || x.out)) {
      _finish(_st.every((x) => x.out) ? PracticeEnd.allOut : PracticeEnd.goal);
      return;
    }
    if (rules.over(this)) _finish(PracticeEnd.goal);
  }

  /// Grille du jeu (null = cible classique).
  PracticeGrid? get grid => rules.grid(this);

  void _finish(PracticeEnd e) {
    _end = e;
    final r = List.generate(players.length, (i) => i)
      ..sort((a, b) => rules.compare(this, a, b));
    final best = r.first;
    _winners = [
      for (final i in r)
        if (rules.compare(this, i, best) == 0) i
    ];
  }
}

// ─── Règles ───

int _value(DartHit? h, BullMode bull) {
  if (h == null) return 0;
  if (h.isBull && bull == BullMode.fat) return 50;
  return h.score;
}

List<DartHit> _numberZones(int n) => n == 25
    ? const [DartHit(25, 1, Ring.outerBull), DartHit(25, 2, Ring.innerBull)]
    : [
        DartHit(n, 1, Ring.singleInner),
        DartHit(n, 1, Ring.singleOuter),
        DartHit(n, 2, Ring.double),
        DartHit(n, 3, Ring.triple),
      ];

String _numLabel(int n) => n == 25 ? 'BULL' : '$n';

abstract class PracticeRules {
  final PracticeSettings s;
  PracticeRules(this.s);

  factory PracticeRules.of(PracticeSettings s) => switch (s.kind) {
        PracticeKind.countUp => _CountUp(s),
        PracticeKind.target20 => _TargetHits(s, 20),
        PracticeKind.targetBull => _TargetHits(s, 25),
        PracticeKind.targetChoice => _TargetHits(s, s.target),
        PracticeKind.targetHat => _TargetHat(s),
        PracticeKind.targetHorse => _TargetHorse(s),
        PracticeKind.halfIt => _Sequence(s, _halfIt, start: 40),
        PracticeKind.deltaShoot => _Sequence(s, _delta, start: 0),
        PracticeKind.rotation => _Rotation(s),
        PracticeKind.shootForce => _ShootForce(s),
        PracticeKind.oniren => _Oniren(s),
        PracticeKind.crCountUp => _CrCountUp(s),
        PracticeKind.crMultiple => _CrMultiple(s),
        PracticeKind.bobs27 => _Bobs27(s),
        PracticeKind.checkout121 => _Checkout121(s),
        PracticeKind.spider => _Spider(s),
        PracticeKind.pirates => _Pirates(s),
        PracticeKind.funMission => _FunMission(s),
        PracticeKind.allFives => _AllFives(s),
        PracticeKind.beyondTop => _BeyondTop(s),
        PracticeKind.kickDown => _KickDown(s),
        PracticeKind.twoLine => _TwoLine(s),
        PracticeKind.shanghai => _Shanghai(s),
        PracticeKind.hyperBull => _HyperBull(s),
        PracticeKind.hideAndSeek => _HideAndSeek(s),
        PracticeKind.killer => _Killer(s),
        PracticeKind.treasureHunt => _Treasure(s),
        PracticeKind.ticTacToe => _TicTacToe(s),
        PracticeKind.baseball => _Baseball(s),
        PracticeKind.golf => _Golf(s),
        PracticeKind.scram => _Scram(s),
        PracticeKind.football => _Football(s),
        PracticeKind.hotPotato => _HotPotato(s),
      };

  void init(PracticeGame g, int p, PracticePlayer st) {}
  void onTurnStart(PracticeGame g, int p) {}
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d);
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {}
  int? roundLimit(PracticeGame g);
  String target(PracticeGame g, int p);
  List<DartHit> zones(PracticeGame g, int p) => const [];
  String info(PracticeGame g, int p) => '';
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).score}';
  String rulesLabel(PracticeGame g) {
    final l = roundLimit(g);
    return l == null ? '' : '$l manches';
  }

  /// Le premier qui finit gagne tout de suite.
  bool get goalEndsGame => false;

  /// Fin de partie propre au jeu (dernier survivant…).
  bool over(PracticeGame g) => false;

  /// Le joueur passe son tour (Treasure Hunt) ; consomme le « passe ».
  bool skipTurn(PracticeGame g, int p) => false;

  PracticeGrid? grid(PracticeGame g) => null;

  /// < 0 si a est mieux classé que b.
  int compare(PracticeGame g, int a, int b) =>
      g.stateOf(b).score.compareTo(g.stateOf(a).score);
}

class _CountUp extends PracticeRules {
  _CountUp(super.s);
  @override
  int? roundLimit(PracticeGame g) => s.roundsOrDefault;
  @override
  String target(PracticeGame g, int p) => 'TOUT COMPTE';
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    d.points = _value(d.hit, s.bull);
    d.ok = d.hit != null;
    g.stateOf(p).score += d.points;
  }

  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return st.darts == 0
        ? ''
        : 'MOYENNE ${(st.score * 3 / st.darts).toStringAsFixed(1)}';
  }
}

/// Target 20 / Bull / Choix de cible : touches sur un numéro.
class _TargetHits extends PracticeRules {
  final int fixed;
  _TargetHits(super.s, this.fixed);

  int _goal() => s.goalOrDefault;
  int targetOf(PracticeGame g, int p) => g.stateOf(p).v['t'] ?? fixed;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.v['t'] = fixed;
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => _goal() == 0 ? 10 : null;
  @override
  String rulesLabel(PracticeGame g) =>
      _goal() == 0 ? '10 manches' : 'Objectif ${_goal()} touches';
  @override
  String target(PracticeGame g, int p) => _numLabel(targetOf(g, p));
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(targetOf(g, p));
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    final n = targetOf(g, p);
    if (h == null || (h.isBull ? 25 : h.number) != n) return;
    final k = h.isBull ? (h.ring == Ring.innerBull ? 2 : 1) : h.multiplier;
    final st = g.stateOf(p);
    st.hits += k;
    st.score = st.hits;
    d.points = k;
    d.ok = true;
    if (_goal() > 0 && st.hits >= _goal()) st.done = true;
  }

  @override
  String scoreText(PracticeGame g, int p) =>
      _goal() == 0 ? '${g.stateOf(p).hits}' : '${g.stateOf(p).hits}/${_goal()}';
  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return st.darts == 0
        ? ''
        : 'RÉUSSITE ${(st.good * 100 / st.darts).round()} %';
  }
}

class _TargetHat extends PracticeRules {
  _TargetHat(super.s);
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => null;
  @override
  String rulesLabel(PracticeGame g) => 'Objectif ${s.goalOrDefault} hat tricks';
  @override
  String target(PracticeGame g, int p) => '3 × ${_numLabel(s.target)}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(s.target);
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    d.ok = h != null && (h.isBull ? 25 : h.number) == s.target;
    if (t.darts.length == 3 && t.darts.every((x) => x.ok)) {
      final st = g.stateOf(p);
      st.hits++;
      st.score = st.hits;
      d.points = 1;
      t.note = 'HAT TRICK';
      if (st.hits >= s.goalOrDefault) st.done = true;
    }
  }

  @override
  String scoreText(PracticeGame g, int p) =>
      '${g.stateOf(p).hits}/${s.goalOrDefault}';
}

class _TargetHorse extends PracticeRules {
  _TargetHorse(super.s);
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => null;
  @override
  String rulesLabel(PracticeGame g) =>
      'Objectif ${s.goalOrDefault} White Horse';
  @override
  String target(PracticeGame g, int p) => '3 TRIPLES 15-20';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        for (var n = 15; n <= 20; n++)
          if (!g.currentTurn.darts.any((d) => d.hit?.number == n && d.ok))
            DartHit(n, 3, Ring.triple)
      ];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    final before = t.darts.sublist(0, t.darts.length - 1);
    d.ok = h != null &&
        h.ring == Ring.triple &&
        h.number >= 15 &&
        h.number <= 20 &&
        !before.any((x) => x.ok && x.hit!.number == h.number);
    if (t.darts.length == 3 && t.darts.every((x) => x.ok)) {
      final st = g.stateOf(p);
      st.hits++;
      st.score = st.hits;
      d.points = 1;
      t.note = 'WHITE HORSE';
      if (st.hits >= s.goalOrDefault) st.done = true;
    }
  }

  @override
  String scoreText(PracticeGame g, int p) =>
      '${g.stateOf(p).hits}/${s.goalOrDefault}';
}

// Half It / Delta Shoot : une cible par manche, rien touché = score ÷ 2
enum _Kind { number, doubles, triples, doubleOrTriple, bull, doubleBull }

class _Step {
  final _Kind kind;
  final int n;
  const _Step(this.kind, [this.n = 0]);

  String get label => switch (kind) {
        _Kind.number => '$n',
        _Kind.doubles => 'DOUBLES',
        _Kind.triples => 'TRIPLES',
        _Kind.doubleOrTriple => 'DOUBLE OU TRIPLE',
        _Kind.bull => 'BULL',
        _Kind.doubleBull => 'DOUBLE BULL',
      };

  bool ok(DartHit? h) {
    if (h == null) return false;
    return switch (kind) {
      _Kind.number => !h.isBull && h.number == n,
      _Kind.doubles => h.ring == Ring.double || h.ring == Ring.innerBull,
      _Kind.triples => h.ring == Ring.triple,
      _Kind.doubleOrTriple => h.ring == Ring.double ||
          h.ring == Ring.triple ||
          h.ring == Ring.innerBull,
      _Kind.bull => h.isBull,
      _Kind.doubleBull => h.ring == Ring.innerBull,
    };
  }

  List<DartHit> get zones => switch (kind) {
        _Kind.number => _numberZones(n),
        _Kind.doubles => [
            for (var i = 1; i <= 20; i++) DartHit(i, 2, Ring.double),
            const DartHit(25, 2, Ring.innerBull)
          ],
        _Kind.triples => [
            for (var i = 1; i <= 20; i++) DartHit(i, 3, Ring.triple)
          ],
        _Kind.doubleOrTriple => [
            for (var i = 1; i <= 20; i++) ...[
              DartHit(i, 2, Ring.double),
              DartHit(i, 3, Ring.triple)
            ],
            const DartHit(25, 2, Ring.innerBull)
          ],
        _Kind.bull => _numberZones(25),
        _Kind.doubleBull => const [DartHit(25, 2, Ring.innerBull)],
      };
}

const _halfIt = [
  _Step(_Kind.number, 15),
  _Step(_Kind.number, 16),
  _Step(_Kind.doubles),
  _Step(_Kind.number, 17),
  _Step(_Kind.number, 18),
  _Step(_Kind.triples),
  _Step(_Kind.number, 19),
  _Step(_Kind.number, 20),
  _Step(_Kind.bull),
];

const _delta = [
  _Step(_Kind.number, 10),
  _Step(_Kind.number, 11),
  _Step(_Kind.number, 12),
  _Step(_Kind.doubleOrTriple),
  _Step(_Kind.number, 13),
  _Step(_Kind.number, 14),
  _Step(_Kind.doubles),
  _Step(_Kind.number, 15),
  _Step(_Kind.number, 16),
  _Step(_Kind.number, 17),
  _Step(_Kind.triples),
  _Step(_Kind.number, 18),
  _Step(_Kind.number, 19),
  _Step(_Kind.number, 20),
  _Step(_Kind.bull),
  _Step(_Kind.doubleBull),
];

class _Sequence extends PracticeRules {
  final List<_Step> steps;
  final int start;
  _Sequence(super.s, this.steps, {required this.start});

  _Step stepOf(PracticeGame g) =>
      steps[(g.round - 1).clamp(0, steps.length - 1)];

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.score = start;
  @override
  int? roundLimit(PracticeGame g) => steps.length;
  @override
  String target(PracticeGame g, int p) => stepOf(g).label;
  @override
  List<DartHit> zones(PracticeGame g, int p) => stepOf(g).zones;
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    if (!stepOf(g).ok(d.hit)) return;
    d.ok = true;
    d.points = _value(d.hit, s.bull);
    g.stateOf(p).score += d.points;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (t.okCount > 0) return;
    final st = g.stateOf(p);
    final before = st.score;
    st.score = st.score ~/ 2;
    t.note = '÷ 2 (-${before - st.score})';
  }
}

class _Rotation extends PracticeRules {
  _Rotation(super.s);

  int targetNumber(PracticeGame g, int p) {
    final step = g.stateOf(p).step;
    return step < 20 ? step + 1 : 25;
  }

  bool _ok(DartHit? h, int n) {
    if (h == null || (h.isBull ? 25 : h.number) != n) return false;
    if (n == 25) return true;
    if (s.has('double')) return h.ring == Ring.double;
    if (s.has('triple')) return h.ring == Ring.triple;
    return true;
  }

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 20;
  @override
  String rulesLabel(PracticeGame g) => s.has('double')
      ? 'Doubles seulement'
      : s.has('triple')
          ? 'Triples seulement'
          : '1 à 20 puis 3 bulls';
  @override
  String target(PracticeGame g, int p) {
    final n = targetNumber(g, p);
    if (n == 25) return 'BULL (${g.stateOf(p).v['bulls'] ?? 0}/3)';
    return s.has('double')
        ? 'D$n'
        : s.has('triple')
            ? 'T$n'
            : '$n';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final n = targetNumber(g, p);
    if (n == 25) return _numberZones(25);
    if (s.has('double')) return [DartHit(n, 2, Ring.double)];
    if (s.has('triple')) return [DartHit(n, 3, Ring.triple)];
    return _numberZones(n);
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final n = targetNumber(g, p);
    if (!_ok(d.hit, n)) return;
    d.ok = true;
    d.points = n;
    st.score += n;
    if (n == 25) {
      final b = (st.v['bulls'] ?? 0) + 1;
      st.v['bulls'] = b;
      if (b >= 3) {
        st.done = true;
        if (g.round < 8) {
          final bonus = (8 - g.round) * 100;
          st.score += bonus;
          t.note = 'BONUS +$bonus';
        }
        return;
      }
    } else {
      st.step++;
    }
    // Touche à la dernière fléchette : 3 fléchettes de plus
    if (t.darts.length == t.maxDarts) t.maxDarts += 3;
  }

  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return 'CIBLE ${st.step >= 20 ? 21 : st.step + 1}/21';
  }
}

class _ShootForce extends PracticeRules {
  _ShootForce(super.s);

  int targetNumber(PracticeGame g, int p) {
    final step = g.stateOf(p).step;
    return step < 20 ? step + 1 : 25;
  }

  @override
  int? roundLimit(PracticeGame g) => 8;
  @override
  String target(PracticeGame g, int p) => _numLabel(targetNumber(g, p));
  @override
  List<DartHit> zones(PracticeGame g, int p) =>
      _numberZones(targetNumber(g, p));
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final n = targetNumber(g, p);
    final h = d.hit;
    if (h == null || (h.isBull ? 25 : h.number) != n) {
      st.streak = 0;
      return;
    }
    st.streak++;
    d.ok = true;
    if (n == 25) {
      d.points = h.ring == Ring.innerBull ? 100000 : 10000;
      st.score += d.points;
      st.done = true;
      return;
    }
    d.points = h.score * st.streak;
    st.score += d.points;
    st.step++;
    final triples = t.darts.where((x) => x.ok && x.hit?.ring == Ring.triple);
    if (t.darts.length == 3 && triples.length == 3) {
      st.score += 3000;
      d.points += 3000;
      t.note = '3 TRIPLES +3000';
    }
  }

  @override
  String info(PracticeGame g, int p) => 'SÉRIE ×${g.stateOf(p).streak}';
}

class _Oniren extends PracticeRules {
  _Oniren(super.s);

  int targetOf(PracticeGame g) => 1 + Random(s.seed * 31 + g.round).nextInt(20);

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.lives = 3;
  @override
  int? roundLimit(PracticeGame g) => 99;
  @override
  String rulesLabel(PracticeGame g) => '3 vies · jusqu\'à 99 manches';
  @override
  String target(PracticeGame g, int p) => '${targetOf(g)}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(targetOf(g));
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    d.ok = h != null && !h.isBull && h.number == targetOf(g);
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final ok = [
      for (final d in t.darts)
        if (d.ok) d.hit!
    ];
    final singles = ok.where((h) => h.multiplier == 1).length;
    final big = ok.where((h) => h.multiplier >= 2).length;
    if (singles >= 2 && big >= 1) {
      st.score++;
      t.note = 'VALIDÉ';
    } else {
      st.lives--;
      t.note = 'VIE PERDUE';
      if (st.lives <= 0) st.out = true;
    }
  }

  @override
  String info(PracticeGame g, int p) =>
      'VIES ${g.stateOf(p).lives.clamp(0, 3)}/3';
}

class _CrCountUp extends PracticeRules {
  _CrCountUp(super.s);
  static const _seq = [20, 19, 18, 17, 16, 15, 25];

  @override
  int? roundLimit(PracticeGame g) => 8;
  @override
  String target(PracticeGame g, int p) =>
      g.round <= 7 ? _numLabel(_seq[g.round - 1]) : '15, 20 OU BULL';
  @override
  List<DartHit> zones(PracticeGame g, int p) => g.round <= 7
      ? _numberZones(_seq[g.round - 1])
      : [..._numberZones(15), ..._numberZones(20), ..._numberZones(25)];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final n = h.isBull ? 25 : h.number;
    final ok =
        g.round <= 7 ? n == _seq[g.round - 1] : const [15, 20, 25].contains(n);
    if (!ok) return;
    d.ok = true;
    d.points = _value(h, s.bull);
    g.stateOf(p).score += d.points;
  }
}

class _CrMultiple extends PracticeRules {
  _CrMultiple(super.s);
  static const _seq = [20, 19, 18, 17, 16, 15, 25];

  /// Numéros bonus (manches 4 et 7) : numéro → multiplicateur.
  Map<int, int> bonus(PracticeGame g) {
    if (g.round != 4 && g.round != 7) return const {};
    final pool = [for (var i = 1; i <= 14; i++) i]
      ..shuffle(Random(s.seed * 17 + g.round));
    final m = g.round == 4 ? const [2, 4, 6] : const [3, 6, 9];
    return {for (var i = 0; i < 3; i++) pool[i]: m[i]};
  }

  int targetOf(PracticeGame g) => _seq[(g.round - 1).clamp(0, 6)];

  @override
  int? roundLimit(PracticeGame g) => 7;
  @override
  String target(PracticeGame g, int p) {
    final b = bonus(g);
    final t = _numLabel(targetOf(g));
    return b.isEmpty
        ? t
        : '$t + ${b.entries.map((e) => '${e.key}×${e.value}').join(' ')}';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        ..._numberZones(targetOf(g)),
        for (final n in bonus(g).keys) ..._numberZones(n),
      ];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final n = h.isBull ? 25 : h.number;
    final k = t.darts.length; // 1re ×1, 2e ×2, 3e ×3
    final st = g.stateOf(p);
    if (n == targetOf(g)) {
      d.ok = true;
      d.points = _value(h, s.bull) * k;
    } else if (bonus(g).containsKey(n)) {
      d.ok = true;
      d.points = h.score * bonus(g)[n]!;
    }
    st.score += d.points;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (t.okCount > 0) return;
    final pen = (targetOf(g) == 25 ? 25 : targetOf(g)) * 3;
    g.stateOf(p).score -= pen;
    t.note = '-$pen';
  }
}

class _Bobs27 extends PracticeRules {
  _Bobs27(super.s);

  List<int> get _seq => [
        for (var n = 1; n <= 20; n++)
          if (!s.has('even') || n.isEven) n,
        25
      ];

  int targetOf(PracticeGame g) => _seq[(g.round - 1).clamp(0, _seq.length - 1)];

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.score = 27;
  @override
  int? roundLimit(PracticeGame g) => _seq.length;
  @override
  String rulesLabel(PracticeGame g) => [
        if (s.has('hard')) 'Hard',
        if (s.has('even')) 'Doubles pairs',
        '${_seq.length} manches',
      ].join(' · ');
  @override
  String target(PracticeGame g, int p) =>
      targetOf(g) == 25 ? 'DOUBLE BULL' : 'D${targetOf(g)}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => targetOf(g) == 25
      ? const [DartHit(25, 2, Ring.innerBull)]
      : [DartHit(targetOf(g), 2, Ring.double)];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    final n = targetOf(g);
    final ok = h != null &&
        (n == 25
            ? h.ring == Ring.innerBull
            : h.ring == Ring.double && h.number == n);
    if (!ok) return;
    d.ok = true;
    d.points = n == 25 ? 50 : n * 2;
    g.stateOf(p).score += d.points;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    if (t.okCount == 0) {
      final n = targetOf(g);
      final pen = n == 25 ? 50 : n * 2;
      st.score -= pen;
      t.note = '-$pen';
    }
    if (s.has('hard') && st.score <= 0) {
      st.out = true;
      t.note = '${t.note ?? ''} ÉLIMINÉ'.trim();
    }
  }
}

class _Checkout121 extends PracticeRules {
  _Checkout121(super.s);
  static const start = 121;
  static const finish = 125;

  int get perAttempt => s.roundsOrDefault; // fléchettes par tentative

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    st.v['target'] = start;
    st.v['rem'] = start;
    st.v['used'] = 0;
    st.score = start;
  }

  @override
  void onTurnStart(PracticeGame g, int p) =>
      g.stateOf(p).v['turnRem'] = g.stateOf(p).v['rem']!;

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) =>
      'Double Out · $perAttempt fléchettes · finir $finish';
  @override
  String target(PracticeGame g, int p) => 'FINIR ${g.stateOf(p).v['target']}';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).v['rem']}';
  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return 'CIBLE ${st.v['target']} · ${perAttempt - st.v['used']!} FL.';
  }

  void _newAttempt(PracticePlayer st, int target) {
    st.v['target'] = target;
    st.v['rem'] = target;
    st.v['turnRem'] = target;
    st.v['used'] = 0;
    st.score = target;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final h = d.hit;
    final v = _value(h, s.bull);
    final rem = st.v['rem']!;
    st.v['used'] = st.v['used']! + 1;
    final left = rem - v;
    final isDouble = h != null &&
        (h.ring == Ring.double ||
            h.ring == Ring.innerBull ||
            (h.isBull && s.bull == BullMode.fat));
    if (h != null && left == 0 && isDouble) {
      d.ok = true;
      d.points = v;
      final target = st.v['target']!;
      t.note = 'RÉUSSI $target';
      if (target >= finish) {
        st.done = true;
        st.score = target + 1;
        return;
      }
      _newAttempt(st, target + 1);
      t.maxDarts = t.darts.length; // la manche s'arrête
      return;
    }
    if (h != null && left < 2) {
      // Bust : retour au score du début de la manche
      st.v['rem'] = st.v['turnRem']!;
      t.note = 'BUST';
      t.maxDarts = t.darts.length;
    } else if (h != null) {
      st.v['rem'] = left;
      d.ok = true;
      d.points = v;
    }
    if (st.v['used']! >= perAttempt) {
      final target = st.v['target']!;
      t.note = 'RATÉ $target';
      _newAttempt(st, max(start, target - 1));
      t.maxDarts = t.darts.length;
    }
  }

  @override
  int compare(PracticeGame g, int a, int b) {
    final c = g.stateOf(b).score.compareTo(g.stateOf(a).score);
    return c != 0
        ? c
        : g.stateOf(a).v['rem']!.compareTo(g.stateOf(b).v['rem']!);
  }
}

class _Spider extends PracticeRules {
  _Spider(super.s);

  int spiderValue(PracticeGame g, int killed) =>
      40 + killed * 10 + Random(s.seed * 13 + killed).nextInt(4) * 5;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    st.v['spider'] = spiderValue(g, 0);
    st.v['rem'] = st.v['spider']!;
  }

  @override
  void onTurnStart(PracticeGame g, int p) =>
      g.stateOf(p).v['turnRem'] = g.stateOf(p).v['rem']!;
  @override
  int? roundLimit(PracticeGame g) => 15;
  @override
  String target(PracticeGame g, int p) =>
      'ARAIGNÉE ${g.stateOf(p).hits + 1} : ${g.stateOf(p).v['rem']}';
  @override
  String info(PracticeGame g, int p) => 'ARAIGNÉES ${g.stateOf(p).hits}/8';
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final h = d.hit;
    if (h == null) return;
    final v = _value(h, s.bull);
    final left = st.v['rem']! - v;
    if (left < 0) {
      st.v['rem'] = st.v['turnRem']!;
      t.note = 'TROP !';
      t.maxDarts = t.darts.length;
      return;
    }
    d.ok = true;
    d.points = v;
    st.score += v;
    st.v['rem'] = left;
    if (left == 0) {
      var kill = st.v['spider']!;
      if (h.multiplier >= 2) kill *= 2; // Arrange
      st.score += kill;
      d.points += kill;
      st.hits++;
      t.note = 'ARAIGNÉE ABATTUE +$kill';
      if (st.hits >= 8) {
        final clear = (15 - g.round) * 500;
        st.score += clear;
        d.points += clear;
        t.note = 'TOUTES ABATTUES +$clear';
        st.done = true;
        return;
      }
      st.v['spider'] = spiderValue(g, st.hits);
      st.v['rem'] = st.v['spider']!;
      st.v['turnRem'] = st.v['rem']!;
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    // Combo : aucune fléchette ratée dans la manche
    if (t.darts.length >= 3 && t.darts.every((d) => d.ok)) {
      final st = g.stateOf(p);
      final bonus = t.darts.fold(0, (a, d) => a + _value(d.hit, s.bull));
      st.score += bonus;
      t.note = '${t.note ?? ''} COMBO +$bonus'.trim();
    }
  }
}

class _Pirates extends PracticeRules {
  _Pirates(super.s);
  static const ship = 200;

  int get _rounds => s.has('kids') ? 12 : 15;

  @override
  int? roundLimit(PracticeGame g) => _rounds;
  @override
  String rulesLabel(PracticeGame g) => [
        if (s.has('kids')) 'Kids',
        if (s.has('master')) 'Master',
        '$_rounds manches',
      ].join(' · ');
  @override
  String target(PracticeGame g, int p) {
    final st = g.stateOf(p);
    if ((st.v['chance'] ?? 0) == 1) return 'CHANCE AU TRÉSOR';
    final hp = ship - (st.v['dmg'] ?? 0);
    return 'NAVIRE ${st.hits + 1} : $hp';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(25);
  @override
  String info(PracticeGame g, int p) => 'NAVIRES COULÉS ${g.stateOf(p).hits}/3';

  int _bullValue(DartHit h) {
    if (s.has('master')) return h.ring == Ring.innerBull ? 50 : 0;
    if (s.has('kids') || s.bull == BullMode.fat) return 50;
    return h.ring == Ring.innerBull ? 50 : 25;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final h = d.hit;
    if (h == null || !h.isBull) return;
    final v = _bullValue(h);
    if (v == 0) return;
    d.ok = true;
    if ((st.v['chance'] ?? 0) == 1) {
      // Chance au trésor : chaque bull = un coffre
      d.points = h.ring == Ring.innerBull ? 500 : 300;
      st.score += d.points;
      return;
    }
    d.points = v;
    st.score += v;
    final dmg = (st.v['dmg'] ?? 0) + v;
    if (dmg >= ship) {
      st.hits++;
      st.v['dmg'] = dmg - ship;
      t.note = 'NAVIRE ${st.hits} COULÉ !';
      if (st.hits >= 3) {
        st.v['chance'] = 1;
        st.v['dmg'] = 0;
        t.maxDarts = t.darts.length; // la chance au trésor arrive
      }
    } else {
      st.v['dmg'] = dmg;
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final chance = st.v['chance'] ?? 0;
    if (chance == 1 && t.note?.contains('COULÉ') != true) {
      // Fin de la chance au trésor : bonus de vitesse
      final bonus = (_rounds - g.round) * 100;
      st.score += bonus;
      t.note = 'TRÉSOR · VITESSE +$bonus';
      st.v['chance'] = 2;
      st.done = true;
    }
  }
}

// ═══ Jeux de fête ═══

int _numOf(DartHit h) => h.isBull ? 25 : h.number;

/// Nombres 1-20 mélangés (tirage fixe par graine).
List<int> _shuffled(int seed, {int from = 1, int to = 20}) =>
    [for (var i = from; i <= to; i++) i]..shuffle(Random(seed));

class _Mission {
  final String label;
  final bool Function(List<DartHit?> hits) ok;
  const _Mission(this.label, this.ok);
}

class _FunMission extends PracticeRules {
  _FunMission(super.s);

  _Mission missionFor(PracticeGame g, int p) {
    final r = Random(s.seed * 101 + g.round * 13 + p);
    final n = 1 + r.nextInt(20);
    final a = 1 + r.nextInt(16);
    int sum(List<DartHit?> h) => h.fold(0, (x, d) => x + _value(d, s.bull));
    bool all(List<DartHit?> h) => h.length == 3 && h.every((d) => d != null);
    final list = <_Mission>[
      _Mission('UN TRIPLE', (h) => h.any((d) => d?.ring == Ring.triple)),
      _Mission('UN DOUBLE', (h) => h.any((d) => d?.ring == Ring.double)),
      _Mission('LE BULL', (h) => h.any((d) => d?.isBull ?? false)),
      _Mission('60 POINTS OU PLUS', (h) => sum(h) >= 60),
      _Mission('MOINS DE 30, SANS RATER', (h) => all(h) && sum(h) < 30),
      _Mission('LE $n',
          (h) => h.any((d) => d != null && !d.isBull && d.number == n)),
      _Mission('3 NUMÉROS DIFFÉRENTS',
          (h) => all(h) && {for (final d in h) _numOf(d!)}.length == 3),
      _Mission('2 FOIS LE MÊME NUMÉRO', (h) {
        final ns = [
          for (final d in h)
            if (d != null) _numOf(d)
        ];
        return ns.toSet().length < ns.length;
      }),
      _Mission('UN TOTAL PAIR, SANS RATER', (h) => all(h) && sum(h).isEven),
      _Mission(
          'UN NUMÉRO DE $a À ${a + 4}',
          (h) => h.any((d) =>
              d != null && !d.isBull && d.number >= a && d.number <= a + 4)),
      _Mission('QUE DES SIMPLES, SANS RATER',
          (h) => all(h) && h.every((d) => d!.multiplier == 1 && !d.isBull)),
      _Mission('UN TOTAL DE 40 À 60', (h) => sum(h) >= 40 && sum(h) <= 60),
    ];
    return list[r.nextInt(list.length)];
  }

  bool get _solo => false;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    st.lives = 4;
    st.score = 4;
  }

  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) =>
      g.players.length == 1 ? 'Seul : atteins 8 vies' : '4 vies chacun';
  @override
  String target(PracticeGame g, int p) => missionFor(g, p).label;
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).lives}';
  @override
  String info(PracticeGame g, int p) => 'VIES · MISSIONS ${g.stateOf(p).hits}';
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    d.ok = d.hit != null;
    d.points = _value(d.hit, s.bull);
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final hits = [for (final d in t.darts) d.hit];
    final ok = missionFor(g, p).ok(hits);
    if (g.players.length == 1 || _solo) {
      if (ok) {
        st.lives++;
        st.hits++;
        t.note = 'MISSION RÉUSSIE';
      } else {
        st.lives--;
        t.note = 'MISSION RATÉE';
      }
      if (st.lives >= 8) st.done = true;
      if (st.lives <= 0) st.out = true;
    } else if (ok) {
      final o = g.stateOf(1 - p);
      st.hits++;
      if (o.lives > 0) {
        o.lives--;
        st.lives++;
      }
      t.note = 'MISSION RÉUSSIE : +1 VIE';
      if (o.lives <= 0) o.out = true;
    } else {
      t.note = 'MISSION RATÉE';
    }
    for (var i = 0; i < g.players.length; i++) {
      g.stateOf(i).score = g.stateOf(i).lives;
    }
  }

  @override
  bool over(PracticeGame g) =>
      g.players.length > 1 &&
      g.players.indexed.where((e) => !g.stateOf(e.$1).out).length <= 1;
}

class _AllFives extends PracticeRules {
  _AllFives(super.s);
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 50;
  @override
  String rulesLabel(PracticeGame g) => 'Objectif ${s.goalOrDefault} pile';
  @override
  String target(PracticeGame g, int p) => 'TOTAL MULTIPLE DE 5';
  @override
  String scoreText(PracticeGame g, int p) =>
      '${g.stateOf(p).score}/${s.goalOrDefault}';
  @override
  String info(PracticeGame g, int p) =>
      'RESTE ${s.goalOrDefault - g.stateOf(p).score}';

  int _val(DartHit? h) {
    if (h == null) return 0;
    if (s.has('nodt') && (h.multiplier >= 2 || h.ring == Ring.innerBull)) {
      return 0;
    }
    return _value(h, s.bull);
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    d.ok = d.hit != null;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final total = t.darts.fold(0, (a, d) => a + _val(d.hit));
    final allIn = t.darts.every((d) => d.hit != null);
    if ((!allIn && !s.has('miss')) || total == 0 || total % 5 != 0) {
      t.note = '$total : PAS UN MULTIPLE DE 5';
      return;
    }
    final pts = total ~/ 5;
    if (st.score + pts > s.goalOrDefault) {
      t.note = 'TROP ! (+$pts)';
      return;
    }
    st.score += pts;
    if (t.darts.isNotEmpty) t.darts.last.points = pts;
    t.note = '$total ÷ 5 = +$pts';
    if (st.score == s.goalOrDefault) st.done = true;
  }
}

class _BeyondTop extends PracticeRules {
  _BeyondTop(super.s);

  int targetFor(PracticeGame g) {
    final ts = g.turns;
    if (ts.length < 2) return 30;
    return ts[ts.length - 2].points;
  }

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.lives = 6;
  @override
  int? roundLimit(PracticeGame g) => 10;
  @override
  String rulesLabel(PracticeGame g) => '6 vies · 10 manches';
  @override
  String target(PracticeGame g, int p) => 'PLUS DE ${targetFor(g)}';
  @override
  String info(PracticeGame g, int p) => 'VIES ${g.stateOf(p).lives}/6';
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    d.ok = d.hit != null;
    d.points = _value(d.hit, s.bull);
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final target = _parse(t.target);
    if (t.points > target) {
      final pts = (t.points - target) ~/ 10;
      st.score += pts;
      t.note = 'BATTU ! +$pts';
    } else {
      st.lives--;
      t.note = 'PAS BATTU : -1 VIE';
      if (st.lives <= 0) st.out = true;
    }
  }

  static int _parse(String label) =>
      int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30;

  @override
  bool over(PracticeGame g) =>
      g.players.length > 1 &&
      List.generate(g.players.length, (i) => i)
              .where((i) => !g.stateOf(i).out)
              .length <=
          1;

  @override
  int compare(PracticeGame g, int a, int b) {
    final oa = g.stateOf(a).out ? 1 : 0, ob = g.stateOf(b).out ? 1 : 0;
    if (oa != ob) return oa - ob;
    return g.stateOf(b).score.compareTo(g.stateOf(a).score);
  }
}

class _KickDown extends PracticeRules {
  _KickDown(super.s);

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 40;
  @override
  String rulesLabel(PracticeGame g) =>
      '0 → ${s.goalOrDefault}${s.has('double') ? ' · fin en double' : ''}';
  @override
  String target(PracticeGame g, int p) => 'ATTEINDRE ${s.goalOrDefault}';
  @override
  String info(PracticeGame g, int p) =>
      'RESTE ${s.goalOrDefault - g.stateOf(p).score}';
  @override
  void onTurnStart(PracticeGame g, int p) =>
      g.stateOf(p).v['start'] = g.stateOf(p).score;

  int _penalty(PracticeGame g) {
    if (s.has('prand')) {
      return const [
        50,
        100,
        150,
        200
      ][Random(s.seed + g.turns.length).nextInt(4)];
    }
    return s.has('p150') ? 150 : 100;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final st = g.stateOf(p);
    final goal = s.goalOrDefault;
    final v = _value(h, s.bull);
    final next = st.score + v;
    final isDouble = h.ring == Ring.double || h.ring == Ring.innerBull;
    final over = next > goal ||
        (s.has('double') && (goal - next == 1 || (next == goal && !isDouble)));
    if (over) {
      final pen = _penalty(g);
      st.score = max(0, (st.v['start'] ?? 0) - pen);
      d.points = -pen;
      t.note = 'OVER SCORE -$pen';
      t.maxDarts = t.darts.length;
      return;
    }
    d.ok = true;
    d.points = v;
    st.score = next;
    if (next == goal) {
      st.done = true;
      return;
    }
    // KICK DOWN : même score qu'un adversaire = il retombe à 0
    final kicked = <String>[];
    for (var i = 0; i < g.players.length; i++) {
      if (i == p) continue;
      final o = g.stateOf(i);
      if (o.score == next && next > 0) {
        o.score = 0;
        kicked.add(g.players[i].name);
      }
    }
    if (kicked.isNotEmpty) t.note = 'KICK DOWN : ${kicked.join(', ')} à 0 !';
  }
}

class _TwoLine extends PracticeRules {
  _TwoLine(super.s);
  static const _stars = {0, 4, 12, 20, 24};

  /// Numéro de chaque case (0 = étoile).
  List<int> cells(PracticeGame g) {
    final mix = (g.shared['mix'] as int?) ?? 0;
    final nums = _shuffled(s.seed * 7 + mix * 131);
    var k = 0;
    return [for (var i = 0; i < 25; i++) _stars.contains(i) ? 0 : nums[k++]];
  }

  Map<int, int> own(PracticeGame g) =>
      (g.shared['own'] ??= <int, int>{}) as Map<int, int>;
  Map<int, int> dmg(PracticeGame g) =>
      (g.shared['dmg'] ??= <int, int>{}) as Map<int, int>;

  int lines(PracticeGame g, int p) {
    final c = cells(g);
    final o = own(g);
    bool mine(int i) => c[i] == 0 || o[c[i]] == p;
    final ls = <List<int>>[
      for (var r = 0; r < 5; r++) [for (var x = 0; x < 5; x++) r * 5 + x],
      for (var x = 0; x < 5; x++) [for (var r = 0; r < 5; r++) r * 5 + x],
      [0, 6, 12, 18, 24],
      [4, 8, 12, 16, 20],
    ];
    return ls.where((l) => l.every(mine)).length;
  }

  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) => '2 lignes + plus de points';
  @override
  String target(PracticeGame g, int p) => 'PRENDS DES NUMÉROS';
  @override
  String info(PracticeGame g, int p) => 'LIGNES ${lines(g, p)}/2';
  @override
  List<DartHit> zones(PracticeGame g, int p) => const [];
  @override
  PracticeGrid grid(PracticeGame g) {
    final o = own(g);
    return PracticeGrid(5, [
      for (final n in cells(g))
        n == 0
            ? const PracticeCell('★', star: true)
            : PracticeCell('$n',
                owner: o[n], sub: (dmg(g)[n] ?? 0) > 0 ? '½' : null),
    ]);
  }

  @override
  void onTurnStart(PracticeGame g, int p) => g.shared['bulls'] = 0;

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final st = g.stateOf(p);
    if (h.isBull) {
      final b = (g.shared['bulls'] as int? ?? 0) + 1;
      g.shared['bulls'] = b;
      if (b == 2) {
        g.shared['mix'] = (g.shared['mix'] as int? ?? 0) + 1;
        t.note = 'NUMÉROS MÉLANGÉS !';
        d.ok = true;
      }
      return;
    }
    final n = h.number;
    final o = own(g);
    final owner = o[n];
    d.ok = true;
    if (owner == null) {
      o[n] = p;
      t.note = '$n PRIS';
    } else if (owner == p) {
      d.points = n;
      st.score += n;
    } else if (h.ring == Ring.triple) {
      o[n] = p;
      dmg(g).remove(n);
      t.note = '$n REPRIS !';
    } else if (h.ring == Ring.double) {
      o.remove(n);
      dmg(g).remove(n);
      t.note = '$n LIBÉRÉ';
    } else {
      final k = (dmg(g)[n] ?? 0) + 1;
      if (k >= 2) {
        o.remove(n);
        dmg(g).remove(n);
        t.note = '$n LIBÉRÉ';
      } else {
        dmg(g)[n] = k;
      }
    }
    if (lines(g, p) >= 2 && st.score > g.stateOf(1 - p).score) st.done = true;
  }

  @override
  bool get goalEndsGame => true;

  @override
  int compare(PracticeGame g, int a, int b) {
    if (g.stateOf(a).done != g.stateOf(b).done) {
      return g.stateOf(a).done ? -1 : 1;
    }
    final l = lines(g, b).compareTo(lines(g, a));
    return l != 0 ? l : g.stateOf(b).score.compareTo(g.stateOf(a).score);
  }
}

class _Shanghai extends PracticeRules {
  _Shanghai(super.s);
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => s.roundsOrDefault;
  @override
  String target(PracticeGame g, int p) => '${g.round}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(g.round);
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null || h.isBull || h.number != g.round) return;
    d.ok = true;
    d.points = h.score;
    g.stateOf(p).score += d.points;
    final rings = {
      for (final x in t.darts)
        if (x.ok) x.hit!.multiplier
    };
    if (rings.containsAll(const {1, 2, 3})) {
      if (s.has('infinity')) {
        final bonus = g.round * 10;
        g.stateOf(p).score += bonus;
        d.points += bonus;
        t.note = 'SHANGHAI +$bonus';
      } else {
        t.note = 'SHANGHAI !';
        g.stateOf(p).done = true;
      }
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (s.has('half') && t.okCount == 0) {
      final st = g.stateOf(p);
      st.score ~/= 2;
      t.note = '÷ 2';
    }
  }

  @override
  int compare(PracticeGame g, int a, int b) {
    if (g.stateOf(a).done != g.stateOf(b).done) {
      return g.stateOf(a).done ? -1 : 1;
    }
    return g.stateOf(b).score.compareTo(g.stateOf(a).score);
  }
}

class _HyperBull extends PracticeRules {
  _HyperBull(super.s);
  @override
  int? roundLimit(PracticeGame g) => 8;
  @override
  String target(PracticeGame g, int p) => 'LE PLUS PRÈS DU CENTRE';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        for (var n = 1; n <= 20; n++) DartHit(n, 1, Ring.singleInner),
        ..._numberZones(25),
      ];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    d.points = switch (h.ring) {
      Ring.innerBull => 100,
      Ring.outerBull => 75,
      Ring.singleInner => 50,
      _ => h.score,
    };
    d.ok = d.points >= 50;
    g.stateOf(p).score += d.points;
  }
}

class _HideAndSeek extends PracticeRules {
  _HideAndSeek(super.s);

  List<int> windows() => _shuffled(s.seed * 3 + 1).take(12).toList()..sort();

  /// Fenêtre → animal (valeur > 0 gentil, < 0 méchant).
  Map<int, int> animals(PracticeGame g) {
    if (g.shared['animals'] == null) {
      final r = Random(s.seed * 5 + 2);
      final w = windows()..shuffle(r);
      g.shared['animals'] = <int, int>{
        for (var i = 0; i < 6; i++) w[i]: 10 + r.nextInt(17) * 10,
        w[6]: -150,
      };
    }
    return g.shared['animals'] as Map<int, int>;
  }

  Set<int> opened(PracticeGame g) => (g.shared['open'] ??= <int>{}) as Set<int>;

  int niceLeft(PracticeGame g) => animals(g)
      .entries
      .where((e) => e.value > 0 && !opened(g).contains(e.key))
      .length;

  @override
  int? roundLimit(PracticeGame g) => 10;
  @override
  String target(PracticeGame g, int p) => 'OUVRE UNE FENÊTRE';
  @override
  String info(PracticeGame g, int p) => 'ANIMAUX ${g.stateOf(p).hits}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        for (final n in windows())
          if (!opened(g).contains(n)) ..._numberZones(n)
      ];
  @override
  PracticeGrid grid(PracticeGame g) {
    final a = animals(g);
    final o = opened(g);
    final who = (g.shared['who'] as Map<int, int>?) ?? const {};
    return PracticeGrid(4, [
      for (final n in windows())
        PracticeCell('$n',
            open: o.contains(n),
            owner: who[n],
            sub: !o.contains(n)
                ? '?'
                : a[n] == null
                    ? 'VIDE'
                    : a[n]! > 0
                        ? '🐾 +${a[n]}'
                        : '👹 ${a[n]}'),
    ]);
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final st = g.stateOf(p);
    final a = animals(g);
    final o = opened(g);
    if (h.isBull) {
      // Un méchant de plus caché derrière une fenêtre fermée (5 au plus)
      final angry = a.values.where((v) => v < 0).length;
      final free = [
        for (final n in windows())
          if (!o.contains(n) && !a.containsKey(n)) n
      ];
      if (angry < 5 && free.isNotEmpty) {
        a[free[Random(s.seed + g.turns.length).nextInt(free.length)]] = -150;
        t.note = 'UN MÉCHANT DE PLUS !';
      }
      return;
    }
    final n = h.number;
    if (!windows().contains(n) || o.contains(n)) return;
    o.add(n);
    ((g.shared['who'] ??= <int, int>{}) as Map<int, int>)[n] = p;
    d.ok = true;
    d.points = switch (h.multiplier) { 3 => 150, 2 => 100, _ => 20 };
    final animal = a[n];
    if (animal != null) {
      d.points += animal;
      if (animal > 0) {
        st.hits++;
        st.v['found'] = (st.v['found'] ?? 0) + 1;
        t.note = 'ANIMAL TROUVÉ +$animal';
      } else {
        t.note = 'LE MÉCHANT ! $animal';
      }
    }
    st.score += d.points;
  }

  @override
  void onTurnStart(PracticeGame g, int p) => g.stateOf(p).v['found'] = 0;

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final found = st.v['found'] ?? 0;
    if (t.okCount == 0) {
      st.score ~/= 2;
      t.note = 'RIEN TOUCHÉ : ÷ 2';
    } else if (found >= 3) {
      st.score += 200;
      t.note = '3 ANIMAUX : +200';
    } else if (found == 0) {
      st.score -= 100;
      t.note = 'AUCUN ANIMAL : -100';
    }
  }

  @override
  bool over(PracticeGame g) => niceLeft(g) == 0;
}

class _Killer extends PracticeRules {
  _Killer(super.s);

  int numberOf(PracticeGame g, int p) => _shuffled(s.seed * 11 + 5)[p % 20];
  int get _need => s.has('onehit') ? 1 : 3;
  bool killer(PracticeGame g, int p) => g.stateOf(p).v['killer'] == 1;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.lives = 0;
  @override
  int? roundLimit(PracticeGame g) => 40;
  @override
  String rulesLabel(PracticeGame g) => [
        if (s.has('double')) 'Doubles',
        if (s.has('triple')) 'Triples',
        if (s.has('onehit')) 'Killer en une touche',
        'Dernier en vie',
      ].join(' · ');
  @override
  String target(PracticeGame g, int p) => killer(g, p)
      ? 'KILLER : VISE LES AUTRES'
      : 'TON NUMÉRO : ${numberOf(g, p)}';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).lives}';
  @override
  String info(PracticeGame g, int p) =>
      'N° ${numberOf(g, p)} · VIES${killer(g, p) ? ' · KILLER' : ''}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => killer(g, p)
      ? [
          for (var i = 0; i < g.players.length; i++)
            if (i != p && !g.stateOf(i).out) ..._numberZones(numberOf(g, i))
        ]
      : _numberZones(numberOf(g, p));

  int _count(DartHit h) {
    if (s.has('double')) return h.ring == Ring.double ? 1 : 0;
    if (s.has('triple')) return h.ring == Ring.triple ? 1 : 0;
    return h.multiplier;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null || h.isBull) return;
    final k = _count(h);
    if (k == 0) return;
    final st = g.stateOf(p);
    if (h.number == numberOf(g, p)) {
      d.ok = true;
      if (killer(g, p)) {
        st.lives = max(0, st.lives - k);
        t.note = 'AÏE, TON PROPRE NUMÉRO !';
        if (st.lives < _need) st.v['killer'] = 0;
      } else {
        st.lives = min(3, st.lives + k);
        if (st.lives >= _need) {
          st.v['killer'] = 1;
          t.note = '${g.players[p].name.toUpperCase()} EST KILLER !';
        }
      }
      d.points = k;
      return;
    }
    if (!killer(g, p)) return;
    for (var i = 0; i < g.players.length; i++) {
      final o = g.stateOf(i);
      if (i == p || o.out || numberOf(g, i) != h.number) continue;
      d.ok = true;
      if (o.lives == 0) {
        o.out = true;
        t.note = '${g.players[i].name.toUpperCase()} ÉLIMINÉ !';
      } else {
        o.lives = max(0, o.lives - k);
        if (o.lives < _need) o.v['killer'] = 0;
        t.note = '${g.players[i].name} -$k';
      }
    }
  }

  @override
  bool over(PracticeGame g) =>
      List.generate(g.players.length, (i) => i)
          .where((i) => !g.stateOf(i).out)
          .length <=
      1;

  @override
  int compare(PracticeGame g, int a, int b) {
    final oa = g.stateOf(a).out ? 1 : 0, ob = g.stateOf(b).out ? 1 : 0;
    if (oa != ob) return oa - ob;
    return g.stateOf(b).lives.compareTo(g.stateOf(a).lives);
  }
}

class _Treasure extends PracticeRules {
  _Treasure(super.s);

  @override
  int? roundLimit(PracticeGame g) => 10;
  @override
  String rulesLabel(PracticeGame g) => 'Manches 3-6-9 ×2 · 4-7-10 inversées';
  @override
  String target(PracticeGame g, int p) => const [3, 6, 9].contains(g.round)
      ? 'TRÉSORS × 2'
      : const [4, 7, 10].contains(g.round)
          ? 'EFFETS INVERSÉS'
          : 'CREUSE UN NUMÉRO';
  @override
  String info(PracticeGame g, int p) =>
      g.stateOf(p).v['shield'] == 1 ? 'BOUCLIER' : '';

  @override
  bool skipTurn(PracticeGame g, int p) {
    final st = g.stateOf(p);
    if (st.v['skip'] == 1) {
      st.v['skip'] = 0;
      return true;
    }
    return false;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final st = g.stateOf(p);
    final dbl = const [3, 6, 9].contains(g.round);
    final inv = const [4, 7, 10].contains(g.round);
    if (h.isBull) {
      t.note = 'CRÂNE DU BULL : TOUR PASSÉ';
      if (g.players.length == 1) {
        st.done = true;
      } else {
        st.v['skip'] = 1;
      }
      t.maxDarts = t.darts.length;
      return;
    }
    final digs = (g.shared['dig'] ??= <int, int>{}) as Map<int, int>;
    final k = digs[h.number] = (digs[h.number] ?? 0) + 1;
    final r = Random(s.seed * 977 + h.number * 31 + k).nextInt(100);
    d.ok = true;
    var delta = 0;
    String what;
    if (r < 30) {
      final n = 1 + r % 5;
      delta = n * 100;
      what = '$n COFFRE${n > 1 ? 'S' : ''}';
    } else if (r < 35) {
      delta = 1000;
      what = 'DIAMANT';
    } else if (r < 38) {
      delta = inv ? -(st.score ~/ 2) : st.score; // lingot : score × 2
      what = inv ? 'LINGOT INVERSÉ ÷ 2' : 'LINGOT D\'OR × 2';
      st.score += delta;
      d.points = delta;
      t.note = what;
      return;
    } else if (r < 53) {
      delta = -100;
      what = 'CRÂNE BLANC';
    } else if (r < 63) {
      delta = -300;
      what = 'CRÂNE VIOLET';
    } else if (r < 69) {
      delta = -500;
      what = 'CRÂNE ROUGE';
    } else if (r < 72) {
      delta = -1000;
      what = 'GRENADE';
    } else if (r < 80) {
      st.v['shield'] = 1;
      t.note = 'BOUCLIER';
      return;
    } else if (r < 92) {
      final steal = r < 88 ? 300 : 600;
      // Vol au joueur qui a le plus de points
      var victim = -1;
      for (var i = 0; i < g.players.length; i++) {
        if (i == p) continue;
        if (victim < 0 || g.stateOf(i).score > g.stateOf(victim).score) {
          victim = i;
        }
      }
      final name = steal == 300 ? 'COUTEAU' : 'ÉPÉE';
      if (victim < 0) {
        delta = steal;
        what = name;
      } else {
        final amount = inv ? -steal : steal;
        g.stateOf(victim).score -= amount;
        st.score += amount;
        d.points = amount;
        t.note = inv
            ? '$name INVERSÉ : ${g.players[victim].name} +$steal'
            : '$name : -$steal à ${g.players[victim].name}';
        return;
      }
    } else {
      t.note = 'RIEN';
      return;
    }
    if (dbl) delta *= 2;
    if (inv) delta = -delta;
    if (delta < 0 && st.v['shield'] == 1) {
      st.v['shield'] = 0;
      t.note = '$what : BOUCLIER !';
      return;
    }
    st.score += delta;
    d.points = delta;
    t.note = '$what ${delta >= 0 ? '+' : ''}$delta';
  }
}

class _TicTacToe extends PracticeRules {
  _TicTacToe(super.s);

  int get size => s.has('big') ? 4 : 3;
  int get need => s.has('mark8') ? 8 : 4;
  List<int> numbers() => _shuffled(s.seed * 19 + 3).take(size * size).toList();

  Map<int, int> owners(PracticeGame g) =>
      (g.shared['own'] ??= <int, int>{}) as Map<int, int>;
  Map<String, int> marks(PracticeGame g) =>
      (g.shared['marks'] ??= <String, int>{}) as Map<String, int>;

  bool hasLine(PracticeGame g, int p) {
    final o = owners(g);
    final ns = numbers();
    bool mine(int r, int c) => o[ns[r * size + c]] == p;
    for (var i = 0; i < size; i++) {
      if (List.generate(size, (c) => mine(i, c)).every((x) => x)) return true;
      if (List.generate(size, (r) => mine(r, i)).every((x) => x)) return true;
    }
    return List.generate(size, (i) => mine(i, i)).every((x) => x) ||
        List.generate(size, (i) => mine(i, size - 1 - i)).every((x) => x);
  }

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 25;
  @override
  String rulesLabel(PracticeGame g) => '$size × $size · $need marques par case';
  @override
  String target(PracticeGame g, int p) => 'PRENDS UNE CASE';
  @override
  String info(PracticeGame g, int p) =>
      '${p == 0 ? 'X' : 'O'} · ${owners(g).values.where((x) => x == p).length} CASES';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        for (final n in numbers())
          if (owners(g)[n] == null || owners(g)[n] == p) ..._numberZones(n)
      ];
  @override
  PracticeGrid grid(PracticeGame g) {
    final o = owners(g);
    final m = marks(g);
    return PracticeGrid(size, [
      for (final n in numbers())
        PracticeCell('$n',
            owner: o[n],
            open: o[n] != null,
            sub: o[n] != null
                ? (o[n] == 0 ? 'X' : 'O')
                : [
                    for (var p = 0; p < g.players.length; p++)
                      if ((m['$n:$p'] ?? 0) > 0)
                        '${p == 0 ? 'X' : 'O'} ${m['$n:$p']}/$need'
                  ].join('  ')),
    ]);
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null || h.isBull || !numbers().contains(h.number)) return;
    final n = h.number;
    final o = owners(g);
    final st = g.stateOf(p);
    if (o[n] == p) {
      d.ok = true;
      d.points = h.score;
      st.score += d.points;
      return;
    }
    if (o[n] != null) return;
    d.ok = true;
    final key = '$n:$p';
    final m = marks(g)[key] = (marks(g)[key] ?? 0) + h.multiplier;
    if (m >= need) {
      o[n] = p;
      st.hits++;
      t.note = 'CASE $n PRISE';
      if (hasLine(g, p)) {
        st.done = true;
        t.note = 'ALIGNÉ !';
      }
    }
  }

  @override
  bool over(PracticeGame g) => owners(g).length == size * size;

  @override
  int compare(PracticeGame g, int a, int b) {
    if (g.stateOf(a).done != g.stateOf(b).done) {
      return g.stateOf(a).done ? -1 : 1;
    }
    return g.stateOf(b).score.compareTo(g.stateOf(a).score);
  }
}

class _Baseball extends PracticeRules {
  _Baseball(super.s);

  bool _tied(PracticeGame g) {
    final scores = [
      for (var i = 0; i < g.players.length; i++) g.stateOf(i).score
    ];
    final best = scores.reduce(max);
    return g.players.length > 1 && scores.where((x) => x == best).length > 1;
  }

  @override
  int? roundLimit(PracticeGame g) {
    if (g.round <= 9) return 9;
    return _tied(g) && g.round <= 12 ? g.round : g.round - 1;
  }

  @override
  String rulesLabel(PracticeGame g) => '9 manches';
  @override
  String target(PracticeGame g, int p) => '${g.round}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(g.round);
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null || h.isBull || h.number != g.round) return;
    d.ok = true;
    d.points = h.multiplier;
    g.stateOf(p).score += d.points;
  }
}

class _Golf extends PracticeRules {
  _Golf(super.s);
  @override
  int? roundLimit(PracticeGame g) => s.roundsOrDefault;
  @override
  String rulesLabel(PracticeGame g) =>
      '${s.roundsOrDefault} trous · le moins de coups gagne';
  @override
  String target(PracticeGame g, int p) => 'TROU ${g.round} : LE ${_hole(g)}';
  int _hole(PracticeGame g) => ((g.round - 1) % 20) + 1;
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(_hole(g));
  @override
  String info(PracticeGame g, int p) => 'COUPS';
  static int _strokes(DartHit? h, int hole) {
    if (h == null || h.isBull || h.number != hole) return 5;
    return switch (h.multiplier) { 3 => 1, 2 => 2, _ => 3 };
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final k = _strokes(d.hit, _hole(g));
    d.ok = k < 5;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final best = t.darts.fold(5, (a, d) => min(a, _strokes(d.hit, _hole(g))));
    g.stateOf(p).score += best;
    t.note = switch (best) {
      1 => 'BIRDIE : 1 COUP',
      2 => 'PAR : 2 COUPS',
      3 => '3 COUPS',
      _ => 'RATÉ : 5 COUPS',
    };
  }

  @override
  int compare(PracticeGame g, int a, int b) =>
      g.stateOf(a).score.compareTo(g.stateOf(b).score);
}

class _Scram extends PracticeRules {
  _Scram(super.s);
  static const _targets = [20, 19, 18, 17, 16, 15, 25];

  int phase(PracticeGame g) => (g.shared['phase'] as int?) ?? 1;
  int stopper(PracticeGame g) => phase(g) == 1 ? 0 : 1;
  Set<int> closed(PracticeGame g) =>
      (g.shared['closed'] ??= <int>{}) as Set<int>;

  @override
  int? roundLimit(PracticeGame g) => 40;
  @override
  String rulesLabel(PracticeGame g) => 'Partie ${phase(g)}/2';
  @override
  String target(PracticeGame g, int p) =>
      p == stopper(g) ? 'FERME LES NUMÉROS' : 'MARQUE SUR LES OUVERTS';
  @override
  String info(PracticeGame g, int p) =>
      p == stopper(g) ? 'FERMEUR' : 'MARQUEUR';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        for (final n in _targets)
          if (!closed(g).contains(n)) ..._numberZones(n)
      ];
  @override
  PracticeGrid grid(PracticeGame g) => PracticeGrid(7, [
        for (final n in _targets)
          PracticeCell(n == 25 ? 'B' : '$n',
              owner: closed(g).contains(n) ? stopper(g) : null,
              open: closed(g).contains(n),
              sub: closed(g).contains(n) ? 'FERMÉ' : 'OUVERT'),
      ]);

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final n = _numOf(h);
    if (!_targets.contains(n) || closed(g).contains(n)) return;
    d.ok = true;
    if (p == stopper(g)) {
      closed(g).add(n);
      if (closed(g).length == _targets.length) {
        if (phase(g) == 1) {
          g.shared['phase'] = 2;
          closed(g).clear();
          t.note = 'TOUT FERMÉ : ON ÉCHANGE !';
          t.maxDarts = t.darts.length;
        } else {
          g.shared['phase'] = 3;
          t.note = 'TOUT FERMÉ : FIN';
        }
      }
    } else {
      d.points = _value(h, s.bull);
      g.stateOf(p).score += d.points;
    }
  }

  @override
  bool over(PracticeGame g) => phase(g) == 3;
}

class _Football extends PracticeRules {
  _Football(super.s);

  int ball(PracticeGame g) => (g.shared['ball'] as int?) ?? -1;

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 40;
  @override
  String rulesLabel(PracticeGame g) => '${s.goalOrDefault} buts pour gagner';
  @override
  String target(PracticeGame g, int p) =>
      ball(g) == p ? 'MARQUE : UN DOUBLE' : 'PRENDS LE BALLON : BULL';
  @override
  String info(PracticeGame g, int p) => ball(g) == p ? 'AU BALLON' : '';
  @override
  List<DartHit> zones(PracticeGame g, int p) => ball(g) == p
      ? [for (var i = 1; i <= 20; i++) DartHit(i, 2, Ring.double)]
      : _numberZones(25);

  @override
  void onTurnStart(PracticeGame g, int p) => g.shared['goals'] = 0;

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final st = g.stateOf(p);
    if (h.isBull) {
      d.ok = true;
      if (ball(g) != p) {
        g.shared['ball'] = p;
        t.note = 'BALLON PRIS !';
      }
      return;
    }
    if (ball(g) == p && h.ring == Ring.double) {
      d.ok = true;
      d.points = 1;
      st.score++;
      g.shared['goals'] = (g.shared['goals'] as int? ?? 0) + 1;
      t.note = 'BUUUT ! ${g.players[p].name}';
      if (st.score >= s.goalOrDefault) st.done = true;
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    // Avec le ballon, une manche sans but le rend
    final hadBall = t.darts.any((d) => d.hit?.isBull ?? false) || ball(g) == p;
    if (ball(g) == p && (g.shared['goals'] as int? ?? 0) == 0 && hadBall) {
      final took = t.darts.any((d) => d.hit?.isBull ?? false);
      if (!took) {
        g.shared['ball'] = -1;
        t.note = 'BALLON PERDU';
      }
    }
  }
}

class _HotPotato extends PracticeRules {
  _HotPotato(super.s);

  int holder(PracticeGame g) => (g.shared['holder'] as int?) ?? 0;
  int number(PracticeGame g) =>
      (g.shared['num'] as int?) ?? 1 + Random(s.seed).nextInt(20);
  int fuse(PracticeGame g) =>
      (g.shared['fuse'] as int?) ?? 3 + Random(s.seed + 1).nextInt(4);

  void _newBomb(PracticeGame g, int to) {
    final k = (g.shared['bombs'] as int? ?? 0) + 1;
    g.shared['bombs'] = k;
    final r = Random(s.seed * 41 + k);
    var n = 1 + r.nextInt(20);
    if (n == number(g)) n = n % 20 + 1;
    g.shared['num'] = n;
    g.shared['fuse'] = 3 + r.nextInt(4);
    g.shared['holder'] = to;
  }

  int _nextAlive(PracticeGame g, int from) {
    final n = g.players.length;
    for (var k = 1; k <= n; k++) {
      final i = (from + k) % n;
      if (!g.stateOf(i).out) return i;
    }
    return from;
  }

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.lives = 3;
  @override
  int? roundLimit(PracticeGame g) => 99;
  @override
  String rulesLabel(PracticeGame g) => '3 vies · dernier survivant';
  @override
  String target(PracticeGame g, int p) =>
      'BOMBE SUR LE ${number(g)} · MÈCHE ${fuse(g)}';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).lives}';
  @override
  String info(PracticeGame g, int p) =>
      'VIES${holder(g) == p ? ' · À LA BOMBE' : ''}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(number(g));

  @override
  bool skipTurn(PracticeGame g, int p) => p != holder(g);

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h != null && !h.isBull && h.number == number(g)) {
      d.ok = true;
      final to = _nextAlive(g, p);
      t.note = 'BOMBE PASSÉE À ${g.players[to].name.toUpperCase()}';
      _newBomb(g, to);
      t.maxDarts = t.darts.length;
      return;
    }
    final left = fuse(g) - 1;
    g.shared['fuse'] = left;
    if (left <= 0) {
      final st = g.stateOf(p);
      st.lives--;
      t.note = 'BOUM ! ${g.players[p].name.toUpperCase()} -1 VIE';
      if (st.lives <= 0) st.out = true;
      _newBomb(g, _nextAlive(g, p));
      t.maxDarts = t.darts.length;
    }
  }

  @override
  bool over(PracticeGame g) =>
      List.generate(g.players.length, (i) => i)
          .where((i) => !g.stateOf(i).out)
          .length <=
      1;

  @override
  int compare(PracticeGame g, int a, int b) {
    final oa = g.stateOf(a).out ? 1 : 0, ob = g.stateOf(b).out ? 1 : 0;
    if (oa != ob) return oa - ob;
    return g.stateOf(b).lives.compareTo(g.stateOf(a).lives);
  }
}
