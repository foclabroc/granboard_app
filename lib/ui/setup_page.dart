import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../board_service.dart';
import '../format.dart';
import '../game/bot.dart';
import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import '../players.dart';
import 'account_page.dart';
import 'game_page.dart';
import 'rules.dart';
import 'setup_widgets.dart';
import 'theme.dart';
import 'widgets.dart';
import 'game_theme.dart';

const kSetupPrefKey = 'x01_setup_v1';
const _prefKey = kSetupPrefKey;
const _maxPlayersDefault = 8;

/// Le Cricket (affichage en colonnes) accepte jusqu'à 10 joueurs.
const _maxPlayersCricket = 10;
const _limits = <int?>[null, 10, 15, 20, 25, 30];
const kTeamNames = ['Équipe A', 'Équipe B'];
const kTeamColors = [Color(0xFFE53935), Color(0xFF1E88E5)];

/// Réglages d'une partie : 01, Cricket, Match, Entraînement, Fête.
class SetupPage extends StatefulWidget {
  /// Famille de jeux ouverte d'office : x01, cricket, match, practice, party.
  final String? kind;

  /// Défi en ligne : moi puis l'adversaire (et mon coéquipier en double :
  /// moi, l'adversaire, mon coéquipier). La page ne lance pas la partie,
  /// elle renvoie son JSON (`Navigator.pop`) pour l'envoyer avec le défi.
  final List<X01Player>? online;

  /// Création d'un tournoi (avec [online] = moi + un adversaire fictif) :
  /// 01 / Cricket / Match seulement, nom et taille du tableau ; renvoie
  /// {game, label, name, size}.
  final bool tournament;

  /// Jeu d'un salon en ligne ([online] = tous les joueurs du salon) :
  /// renvoie le JSON de la partie avec « label » et « order »
  /// (fixed = maisons en alternance, random = au hasard).
  final bool salon;
  const SetupPage(
      {super.key,
      this.kind,
      this.online,
      this.tournament = false,
      this.salon = false});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final store = PlayerStore.instance;

  int _start = 501;
  bool _freeze = false;
  InRule _in = InRule.open;
  OutRule _out = OutRule.double;
  BullMode _bull = BullMode.split;
  int? _limit;
  // Cricket
  String _kind = 'x01';
  CricketVariant _variant = CricketVariant.standard;
  bool _cTeams = false;
  int? _cLimit = 20;
  // Entraînement
  PracticeKind _pKind = PracticeKind.countUp;
  PracticeKind _fKind = PracticeKind.funMission;
  int? _pRounds;
  int? _pGoal;
  int _pTarget = 20;
  final Set<String> _pOptions = {};
  // Match
  int _mLegs = 3;
  List<LegKind> _mPattern = MatchSettings.alternate(13);

  /// Score de départ de chaque leg de 01 du Medley.
  List<int> _mStarts = List.filled(13, 501);

  /// Jeu du leg [i] : son score de départ, ou 0 pour le Cricket.
  int _legGame(int i) => _mPattern[i] == LegKind.x01 ? _mStarts[i] : 0;
  void _setLegGame(int i, int v) => setState(() {
        _mPattern[i] = v == 0 ? LegKind.cricket : LegKind.x01;
        if (v != 0) _mStarts[i] = v;
      });
  String _legText(int v) => v == 0 ? 'Cricket' : '$v';
  final List<String> _selected = [];
  final Map<String, int> _team = {};

  bool get _online => widget.online != null;

  /// Défi en ligne en double (2 contre 2, une maison par équipe) : 01 avec
  /// score d'équipe ou Team Cricket.
  bool get _double => !widget.salon && (widget.online?.length ?? 0) == 3;

  /// Ouvert depuis une tuile de l'accueil : le choix du jeu est masqué.
  bool get _fixed => widget.kind != null && !_online;

  String get _familyName => switch (_kind) {
        'cricket' => 'CRICKET',
        'match' => 'MEDLEY',
        'practice' => 'ENTRAÎNEMENT',
        'party' => 'PARTY',
        _ => '01',
      };

  /// En ligne, qui commence : 0 moi, 1 l'adversaire, 2 au hasard.
  int _first = 2;

  @override
  void initState() {
    super.initState();
    // Hors partie : les couleurs des comptes
    store.gameColors.clear();
    _load();
  }

  Future<void> _load() async {
    if (widget.kind != null) setState(() => _kind = widget.kind!);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString(_prefKey);
    if (raw == null) {
      if (_double) setState(() => _kind = 'x01');
      return _selectOwner();
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _apply(j);
        _selected
          ..clear()
          ..addAll([
            for (final id in (j['players'] as List? ?? const []))
              if (store.byId(id as String) != null || isGuestId(id)) id
          ]);
        _team
          ..clear()
          ..addAll({
            for (final e in (j['teams'] as Map? ?? const {}).entries)
              e.key as String: e.value as int
          });
      });
    } catch (_) {}
    if (_double && _kind != 'x01' && _kind != 'cricket' && mounted) {
      setState(() => _kind = 'x01');
    }
    _selectOwner();
  }

  /// Applique des réglages enregistrés (dernière partie ou favori).
  void _apply(Map<String, dynamic> j) {
    _start = j['start'] as int? ?? 501;
    _freeze = j['freeze'] as bool? ?? false;
    _in = InRule.values[j['in'] as int? ?? 0];
    _out = OutRule.values[j['out'] as int? ?? 1];
    _bull = BullMode.values[j['bull'] as int? ?? 0];
    _limit = j['limit'] as int?;
    _kind = widget.kind ?? j['kind'] as String? ?? 'x01';
    _variant = CricketVariant.values.firstWhere((v) => v.name == j['variant'],
        orElse: () => CricketVariant.standard);
    _cTeams = j['cteams'] as bool? ?? false;
    _cLimit = j.containsKey('climit') ? j['climit'] as int? : 20;
    _mLegs = j['mlegs'] as int? ?? 3;
    _fKind = PracticeKind.values.firstWhere((k) => k.name == j['fkind'],
        orElse: () => PracticeKind.funMission);
    _pKind = PracticeKind.values.firstWhere((k) => k.name == j['pkind'],
        orElse: () => PracticeKind.countUp);
    _pRounds = j['prounds'] as int?;
    _pGoal = j['pgoal'] as int?;
    _pTarget = j['ptarget'] as int? ?? 20;
    _pOptions
      ..clear()
      ..addAll([for (final o in (j['popt'] as List? ?? const [])) '$o']);
    final mp = [
      for (final k in (j['mpattern'] as List? ?? const []))
        LegKind.values.firstWhere((x) => x.name == k, orElse: () => LegKind.x01)
    ];
    _mPattern = [
      for (var i = 0; i < 13; i++)
        i < mp.length ? mp[i] : MatchSettings.alternate(13)[i]
    ];
    final ms = [for (final v in (j['mstarts'] as List? ?? const [])) v];
    _mStarts = [
      for (var i = 0; i < 13; i++)
        i < ms.length && ms[i] is int && kStartScores.contains(ms[i])
            ? ms[i] as int
            : _start
    ];
  }

  /// Jeu et règles en cours (sans les joueurs) : favoris.
  Map<String, dynamic> get _rulesJson => {
        'start': _start,
        'freeze': _freeze,
        'in': _in.index,
        'out': _out.index,
        'bull': _bull.index,
        'limit': _limit,
        'kind': _kind,
        'variant': _variant.name,
        'cteams': _cTeams,
        'climit': _cLimit,
        'mlegs': _mLegs,
        'pkind': _pKind.name,
        'fkind': _fKind.name,
        'prounds': _pRounds,
        'pgoal': _pGoal,
        'ptarget': _pTarget,
        'popt': _pOptions.toList(),
        'mpattern': [for (final k in _mPattern) k.name],
        'mstarts': _mStarts,
      };

  /// Aucun joueur choisi (premier lancement…) : le profil principal est
  /// coché d'office.
  void _selectOwner() {
    // Tournoi : pas d'entraînement ni de fête (il faut un vainqueur)
    if (widget.tournament && _practiceOn && mounted) {
      setState(() => _kind = 'x01');
    }
    final me = store.owner;
    if (_online ||
        !mounted ||
        _selected.isNotEmpty ||
        me == null ||
        me.expired) {
      return;
    }
    setState(() => _selected.add(me.key));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey,
        jsonEncode({
          'start': _start,
          'freeze': _freeze,
          'in': _in.index,
          'out': _out.index,
          'bull': _bull.index,
          'limit': _limit,
          'kind': _kind,
          'variant': _variant.name,
          'cteams': _cTeams,
          'climit': _cLimit,
          'mlegs': _mLegs,
          'pkind': _pKind.name,
          'fkind': _fKind.name,
          'prounds': _pRounds,
          'pgoal': _pGoal,
          'ptarget': _pTarget,
          'popt': _pOptions.toList(),
          'mpattern': [for (final k in _mPattern) k.name],
          'mstarts': _mStarts,
          'players': _selected,
          'teams': _team,
        }));
  }

  X01Settings get _settings => X01Settings(
        startScore: _start,
        inRule: _in,
        outRule: _out,
        bullMode: _bull,
        roundLimit: _limit,
        freeze: _freeze && !_online,
        doubles: _double,
      );

  CricketSettings get _cricket => CricketSettings(
        variant: _variant,
        teams: (_cTeams && !_online) || _double,
        roundLimit: _cLimit,
        seed: DateTime.now().microsecondsSinceEpoch,
      );

  bool get _cricketOn => _kind == 'cricket';
  int get _maxPlayers => widget.tournament
      ? 16
      : _cricketOn
          ? _maxPlayersCricket
          : _maxPlayersDefault;

  /// Tournoi à la maison (joueurs du téléphone, matchs sur cette cible).
  bool get _localTournament => widget.tournament && !_online;
  bool get _matchOn => _kind == 'match';
  bool get _practiceOn => _kind == 'practice' || _kind == 'party';
  bool get _partyOn => _kind == 'party';

  PracticeKind get _curKind => _partyOn ? _fKind : _pKind;
  set _curKind(PracticeKind k) => _partyOn ? _fKind = k : _pKind = k;

  PracticeInfo get _pInfo => kPracticeInfo[_curKind]!;

  PracticeSettings get _practice => PracticeSettings(
        _curKind,
        rounds: _pInfo.rounds != null &&
                _pInfo.rounds!.contains(_pRounds ?? _pInfo.defaultRounds)
            ? _pRounds ?? _pInfo.defaultRounds
            : null,
        goal: _pInfo.goals != null &&
                _pInfo.goals!.contains(_pGoal ?? _pInfo.defaultGoal)
            ? _pGoal ?? _pInfo.defaultGoal
            : null,
        target: _pTarget,
        bull: _bull,
        options: {
          for (final o in _pOptions)
            if (_pInfo.options.containsKey(o)) o
        },
        seed: DateTime.now().microsecondsSinceEpoch,
      );

  MatchSettings get _match => MatchSettings(
        legs: _mLegs,
        pattern: _mPattern.take(_mLegs).toList(),
        starts: _mStarts.take(_mLegs).toList(),
        x01: X01Settings(
            startScore: _start, inRule: _in, outRule: _out, bullMode: _bull),
        cricket: CricketSettings(
            roundLimit: 20, seed: DateTime.now().microsecondsSinceEpoch),
      );

  /// Jeu en équipes (Freeze ou Team Cricket).
  bool get _teams => _matchOn || _practiceOn || _online || widget.tournament
      ? false
      : _cricketOn
          ? _cTeams
          : _freeze;

  String get _gameName => _practiceOn
      ? _pInfo.name
      : _matchOn
          ? 'Medley $_mLegs legs'
          : _cricketOn
              ? _cricket.name
              : _settings.name;

  /// Règles du jeu choisi, avec les réglages en cours.
  String get _rulesText => _practiceOn
      ? practiceRules(_practice)
      : _matchOn
          ? matchFullRules(_match)
          : _cricketOn
              ? cricketRules(_cricket)
              : x01Rules(_settings);

  int _teamOf(String id) => _team[id] ?? 0;

  String _nameOf(String id) => isBotId(id)
      ? 'Joueur virtuel ${id.substring(9)}'
      : isGuestId(id)
          ? 'Invité ${id.substring(6)}'
          : store.byId(id)?.name ?? '?';

  /// Joueur virtuel : son niveau suit celui des joueurs humains de la partie.
  void _addBot() {
    var n = 1;
    while (_selected.contains('guest-bot$n')) {
      n++;
    }
    _select('guest-bot$n');
  }

  void _addGuest() {
    var n = 1;
    while (_selected.contains('guest-$n')) {
      n++;
    }
    _select('guest-$n');
  }

  /// Joueurs dans l'ordre de lancer (Freeze : équipes en alternance).
  List<X01Player> get _order {
    final on = widget.online;
    if (on != null && on.length == 3) {
      // Double : moi et mon coéquipier (équipe 0) contre l'adversaire (1) ;
      // son coéquipier est ajouté quand il accepte
      final swap = _first == 1 ||
          (_first == 2 && DateTime.now().microsecondsSinceEpoch.isOdd);
      final me = X01Player(id: on[0].id, name: on[0].name, team: 0);
      final opp = X01Player(id: on[1].id, name: on[1].name, team: 1);
      final mate = X01Player(id: on[2].id, name: on[2].name, team: 0);
      return swap ? [opp, me, mate] : [me, opp, mate];
    }
    if (on != null && widget.salon) {
      return [
        for (var i = 0; i < on.length; i++)
          X01Player(id: on[i].id, name: on[i].name, team: i)
      ];
    }
    if (on != null) {
      final swap = _first == 1 ||
          (_first == 2 && DateTime.now().microsecondsSinceEpoch.isOdd);
      final ps = swap ? on.reversed.toList() : on;
      return [
        for (var i = 0; i < ps.length; i++)
          X01Player(id: ps[i].id, name: ps[i].name, team: i)
      ];
    }
    X01Player mk(String id, int team) =>
        X01Player(id: id, name: _nameOf(id), team: team);
    if (!_teams) {
      return [for (var i = 0; i < _selected.length; i++) mk(_selected[i], i)];
    }
    final a = _selected.where((id) => _teamOf(id) == 0).toList();
    final b = _selected.where((id) => _teamOf(id) == 1).toList();
    // Équipes en alternance ; si elles sont inégales (choix en cours),
    // les joueurs en trop suivent (la partie ne se lance pas, voir _problem)
    final n = a.length > b.length ? a.length : b.length;
    return [
      for (var i = 0; i < n; i++) ...[
        if (i < a.length) mk(a[i], 0),
        if (i < b.length) mk(b[i], 1),
      ]
    ];
  }

  String? get _problem {
    final n = _online ? widget.online!.length : _selected.length;
    if (n == 0) return 'Ajoute au moins un joueur';
    if (_localTournament) {
      if (n < 2) return 'Il faut au moins 2 joueurs';
      if (_tnName.text.trim().isEmpty) return 'Donne un nom au tournoi';
    }
    if (n > _maxPlayers) return '$_maxPlayers joueurs maximum pour ce jeu';
    if (_practiceOn) {
      final i = _pInfo;
      if (n < i.minPlayers) {
        return '${i.name} : ${i.minPlayers} joueurs minimum';
      }
      if (n > i.maxPlayers) {
        return '${i.name} : ${i.maxPlayers} joueur${i.maxPlayers > 1 ? 's' : ''} maximum';
      }
    }
    if (_teams) {
      final a = _selected.where((id) => _teamOf(id) == 0).length;
      final b = _selected.length - a;
      if (a == 0 || b == 0) {
        return _cricketOn
            ? 'Le Team Cricket se joue à 2 équipes'
            : 'Le Freeze se joue à 2 équipes';
      }
      if (a != b) return 'Les 2 équipes doivent avoir autant de joueurs';
    }
    return null;
  }

  Future<void> _newPlayer() async {
    final p = await showAccountPage(context);
    if (p == null || !mounted) return;
    if (_selected.length < _maxPlayers && !_selected.contains(p.key)) {
      _select(p.key);
    }
  }

  /// Fenêtre « Ajouter des joueurs » : mes joueurs (un toucher = ajouté),
  /// invité, joueur virtuel, nouveau compte. Reste ouverte pour en ajouter
  /// plusieurs.
  Future<void> _addSheet() async {
    await showAppSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final full = _selected.length >= _maxPlayers;
        final available =
            store.players.where((p) => !_selected.contains(p.key)).toList();
        void act(VoidCallback f) {
          f();
          set(() {});
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('AJOUTER DES JOUEURS',
                        style: Tv.title(22, color: Tv.goldLight)),
                  ),
                  Text('${_selected.length}/$_maxPlayers',
                      style: Tv.title(18, color: full ? Tv.red : Tv.text)),
                ],
              ),
              const SizedBox(height: 8),
              Text('MES JOUEURS', style: Tv.label(12, color: Tv.gold)),
              const SizedBox(height: 6),
              if (available.isEmpty)
                Text('Tous tes joueurs sont déjà dans la partie.',
                    style: Tv.label(12))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in available)
                      ActionChip(
                        key: ValueKey('add-${p.key}'),
                        avatar: PlayerAvatar.of(p, size: 24),
                        label: Text(p.expired ? '${p.name} ⚠' : p.name,
                            style: Tv.title(16)),
                        onPressed:
                            full ? null : () => act(() => _select(p.key)),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              Text('AUTRES', style: Tv.label(12, color: Tv.gold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    key: const ValueKey('add-guest'),
                    avatar: const Icon(Icons.person_outline, size: 20),
                    label: Text('Invité', style: Tv.title(16)),
                    onPressed: full ? null : () => act(_addGuest),
                  ),
                  ActionChip(
                    key: const ValueKey('add-bot'),
                    avatar: const Icon(Icons.smart_toy_outlined, size: 20),
                    label: Text('Joueur virtuel', style: Tv.title(16)),
                    onPressed: full ? null : () => act(_addBot),
                  ),
                  ActionChip(
                    key: const ValueKey('add-account'),
                    avatar: const Icon(Icons.person_add, size: 20),
                    label: Text('Nouveau joueur', style: Tv.title(16)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _newPlayer();
                    },
                  ),
                ],
              ),
              const SetupNote('Invités et joueurs virtuels jouent sans stats. '
                  'Le joueur virtuel prend le niveau de ses adversaires.'),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: FilledButton(
                  key: const ValueKey('add-done'),
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      Text('TERMINÉ', style: Tv.title(20, color: Colors.black)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Retire tous les joueurs choisis.
  void _clearPlayers() => setState(() {
        _selected.clear();
        _team.clear();
      });

  void _select(String id) {
    setState(() {
      _selected.add(id);
      // Freeze : équilibre automatiquement les équipes
      final a = _selected.where((x) => x != id && _teamOf(x) == 0).length;
      final b = _selected.length - 1 - a;
      _team[id] = a <= b ? 0 : 1;
    });
  }

  Future<void> _startGame() async {
    await _save();
    if (!mounted) return;
    if (_localTournament) {
      final players = _order;
      final DartsGame g = _matchOn
          ? MatchGame(_match, players.take(2).toList())
          : _cricketOn
              ? CricketGame(_cricket, players.take(2).toList())
              : X01Game(_settings, players.take(2).toList());
      Navigator.pop(context, {
        'game': g.toJson(),
        'label': _gameName,
        'name': _tnName.text.trim(),
        'players': [for (final p in players) p.toJson()],
      });
      return;
    }
    if (_online) {
      final DartsGame g = _practiceOn
          ? PracticeGame(_practice, _order)
          : _matchOn
              ? MatchGame(_match, _order)
              : _cricketOn
                  ? CricketGame(_cricket, _order)
                  : X01Game(_settings, _order);
      final json = g.toJson();
      if (widget.salon) {
        json['label'] = _gameName;
        json['order'] = _first == 2 ? 'random' : 'fixed';
      }
      if (_double) {
        final on = widget.online!;
        json['double'] = true;
        json['home'] = {on[0].id: 'a', on[2].id: 'a', on[1].id: 'b'};
      }
      Navigator.pop(context, json);
      return;
    }
    if (!BoardService.instance.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cible non connectée : connecte-la pour jouer')));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _practiceOn
              ? GamePage(game: PracticeGame(_practice, _order))
              : _matchOn
                  ? GamePage(game: MatchGame(_match, _order))
                  : _cricketOn
                      ? GamePage(game: CricketGame(_cricket, _order))
                      : GamePage(settings: _settings, players: _order)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      GameThemeScope(skin: GameSkins.of(_kind, _kind == 'practice' ? _pKind : _kind == 'party' ? _fKind : null), child: _themedBuild(context));

  Widget _themedBuild(BuildContext context) {
    final problem = _problem;
    final available =
        store.players.where((p) => !_selected.contains(p.key)).toList();
    final full = _selected.length >= _maxPlayers;
    final short = MediaQuery.sizeOf(context).height < 380;
    final chipDensity = short ? VisualDensity.compact : null;
    return _broadcast(problem, available, full, chipDensity);
  }

  // ─── Mise en page « retransmission » (parties à la maison, tournoi) ───

  /// Favoris : à part pour chaque tuile (et pour le tournoi à la maison).
  String get _favTile => _localTournament ? 'tournament' : _kind;
  List<SetupFavorite> _favs = [];
  String? _favsOf;

  bool _favLoading = false;

  Future<void> _loadFavs() async {
    final tile = _favTile;
    if (_favLoading) return;
    _favLoading = true;
    final f = await SetupFavorites.of(tile);
    _favLoading = false;
    if (mounted) {
      setState(() {
        _favs = f;
        _favsOf = tile;
      });
    }
  }

  /// Nom court de la partie (favori, bandeau du bas).
  String get _summary {
    if (_practiceOn) {
      final i = _pInfo;
      final parts = [
        i.name,
        if (i.rounds != null) '${_pRounds ?? i.defaultRounds} manches',
        if (i.target) 'cible ${_pTarget == 25 ? 'bull' : _pTarget}',
      ];
      return parts.join(' · ');
    }
    if (_matchOn) {
      return 'Medley $_mLegs legs · ${_match.patternLabel} · ${_out.label}';
    }
    if (_cricketOn) {
      return '${_cricket.name}${_cLimit == null ? '' : ' · $_cLimit manches'}';
    }
    return [
      _settings.name,
      if (_in != InRule.open) _in.label,
      _out.label,
      if (_limit != null) '$_limit manches',
    ].join(' · ');
  }

  Future<void> _addFavorite() async {
    final ok =
        await SetupFavorites.add(_favTile, SetupFavorite(_summary, _rulesJson));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(ok
              ? '« $_summary » ajouté aux favoris'
              : _favs.length >= SetupFavorites.max
                  ? '${SetupFavorites.max} favoris maximum : appui long sur un favori pour le retirer'
                  : 'Déjà dans les favoris')));
    _loadFavs();
  }

  Future<void> _removeFavorite(int i) async {
    final f = _favs[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer « ${f.label} » ?', style: Tv.title(20)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ANNULER')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('RETIRER')),
        ],
      ),
    );
    if (ok != true) return;
    await SetupFavorites.remove(_favTile, i);
    _loadFavs();
  }

  Widget _favBar() {
    if (_favsOf != _favTile) _loadFavs();
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.star, size: 16, color: Tv.gold),
          const SizedBox(width: 4),
          Text('FAVORIS', style: Tv.label(11, color: Tv.gold)),
          const SizedBox(width: 8),
          Expanded(
            child: _favs.isEmpty
                ? Text('Touche FAVORI en bas pour garder ces réglages',
                    style: Tv.label(11))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final f = _favs[i];
                      final on =
                          jsonEncode(f.settings) == jsonEncode(_rulesJson);
                      return Center(
                        child: Material(
                          color: on
                              ? Color.lerp(Tv.panel2, Tv.gold, 0.25)
                              : Tv.panel2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                  color: on ? Tv.gold : Tv.goldDark)),
                          child: InkWell(
                            key: ValueKey('fav-$i'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _apply(f.settings)),
                            onLongPress: () => _removeFavorite(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star,
                                      size: 14, color: Tv.goldLight),
                                  const SizedBox(width: 4),
                                  Text(f.label,
                                      style: Tv.title(14, color: Tv.goldLight)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  /// Colonne 1 : le jeu (mode, variante, jeu d'entraînement, legs).
  List<Widget> _gameItems() {
    if (_practiceOn) {
      return [
        for (final k in PracticeKind.values)
          if (kPracticeInfo[k]!.party == _partyOn)
            SetupItem(
              key: ValueKey('game-${k.name}'),
              label: kPracticeInfo[k]!.name,
              icon: practiceIcon(k),
              selected: _curKind == k,
              onTap: () => setState(() {
                _curKind = k;
                _pRounds = null;
                _pGoal = null;
              }),
            ),
      ];
    }
    if (_cricketOn) {
      return [
        for (final v in CricketVariant.values)
          SetupItem(
            key: ValueKey('game-${v.name}'),
            label: v.label,
            icon: cricketIcon(v),
            selected: _variant == v,
            onTap: () => setState(() => _variant = v),
          ),
      ];
    }
    if (_matchOn) {
      return [
        for (final n in kMatchLegs)
          SetupItem(
            label: '$n legs',
            icon: Icons.emoji_events_outlined,
            value: '${n ~/ 2 + 1} pour gagner',
            selected: _mLegs == n,
            onTap: () => setState(() => _mLegs = n),
          ),
      ];
    }
    return [
      for (final s in kStartScores)
        SetupItem(
          key: ValueKey('game-$s'),
          label: '$s',
          icon: x01Icon(s),
          selected: _start == s,
          onTap: () => setState(() => _start = s),
        ),
      if (!widget.tournament && !_online)
        SetupSwitch(
          label: 'Freeze (équipes)',
          icon: Icons.ac_unit,
          value: _freeze,
          onChanged: (v) => setState(() => _freeze = v),
        ),
    ];
  }

  /// Colonne 2 : les règles du jeu choisi.
  List<Widget> _ruleItems() {
    String inOut(Enum r) => r.name == 'open'
        ? 'Open'
        : r.name == 'double'
            ? 'Double'
            : 'Master';
    final x01 = [
      SetupPick<InRule>(
          label: 'Début',
          value: _in,
          values: InRule.values,
          text: inOut,
          onChanged: (v) => setState(() => _in = v)),
      SetupPick<OutRule>(
          label: 'Fin',
          value: _out,
          values: OutRule.values,
          text: inOut,
          onChanged: (v) => setState(() => _out = v)),
      SetupPick<BullMode>(
          label: 'Bull',
          value: _bull,
          values: BullMode.values,
          text: (b) => b == BullMode.split ? '25 / 50' : '50 / 50',
          onChanged: (v) => setState(() => _bull = v)),
    ];
    if (_practiceOn) {
      final i = _pInfo;
      return [
        if (i.goals != null)
          SetupPick<int>(
              label: i.goalLabel,
              value: _pGoal ?? i.defaultGoal!,
              values: i.goals!,
              text: (n) => n == 0 ? 'En 10 manches' : '$n',
              onChanged: (v) => setState(() => _pGoal = v)),
        if (i.rounds != null)
          SetupPick<int>(
              label: _curKind == PracticeKind.checkout121
                  ? 'Fléchettes'
                  : 'Manches',
              value: _pRounds ?? i.defaultRounds!,
              values: i.rounds!,
              text: (n) => '$n',
              onChanged: (v) => setState(() => _pRounds = v)),
        if (i.target)
          SetupPick<int>(
              label: 'Cible',
              value: _pTarget,
              values: [for (var n = 20; n >= 1; n--) n, 25],
              text: (n) => n == 25 ? 'Bull' : '$n',
              onChanged: (v) => setState(() => _pTarget = v)),
        for (final o in i.options.entries)
          SetupSwitch(
              label: o.value,
              value: _pOptions.contains(o.key),
              onChanged: (v) => setState(() {
                    if (v && (o.key == 'double' || o.key == 'triple')) {
                      _pOptions.removeAll({'double', 'triple'});
                    }
                    v ? _pOptions.add(o.key) : _pOptions.remove(o.key);
                  })),
        if (i.bull) x01[2],
        SetupNote(i.help),
      ];
    }
    if (_cricketOn) {
      return [
        SetupPick<int?>(
            label: 'Manches',
            value: _cLimit,
            values: kCricketRoundLimits,
            text: (l) => l == null ? 'Sans limite' : '$l',
            onChanged: (v) => setState(() => _cLimit = v)),
        if (!widget.tournament && !_online)
          SetupSwitch(
              label: 'Équipes',
              icon: Icons.groups,
              value: _cTeams,
              onChanged: (v) => setState(() => _cTeams = v)),
        SetupNote(_variant.help),
      ];
    }
    if (_matchOn) {
      return [
        for (var i = 0; i < _mLegs; i++)
          SetupPick<int>(
              key: ValueKey('mleg-$i'),
              label: 'Leg ${i + 1}',
              value: _legGame(i),
              values: const [...kStartScores, 0],
              text: _legText,
              onChanged: (v) => _setLegGame(i, v)),
        const SetupNote(
            'Touche un leg pour choisir son jeu : 301, 501, 701, 901 ou '
            'Cricket. Les règles ci-dessous valent pour tous les legs de 01. '
            'Cricket : règles Standard, 20 manches.'),
        ...x01,
      ];
    }
    return [
      ...x01,
      SetupPick<int?>(
          label: 'Manches',
          value: _limit,
          values: _limits,
          text: (l) => l == null ? 'Sans limite' : '$l',
          onChanged: (v) => setState(() => _limit = v)),
      if (_freeze && !widget.tournament && !_online)
        const SetupNote('Freeze : une équipe dont le total restant dépasse '
            'celui de l\'adversaire est gelée et ne peut pas finir.'),
    ];
  }

  Widget _broadcast(String? problem, List<PlayerProfile> available, bool full,
      VisualDensity? chipDensity) {
    final first = _order.isEmpty ? null : _order.first.name;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SetupBand(
              title: _localTournament
                  ? 'Tournoi à la maison'
                  : widget.tournament
                      ? 'Tournoi en ligne'
                      : widget.salon
                          ? 'Salon'
                          : _online
                              ? 'Défi'
                              : _fixed
                                  ? _familyName
                                  : 'Nouvelle partie',
              sub: widget.salon
                  ? 'Jeu de la partie'
                  : _online && !widget.tournament
                      ? 'contre ${widget.online![1].name}'
                          '${_double ? ' en double' : ''}'
                      : 'Configuration',
              actions: [RulesButton(title: _gameName, text: _rulesText)],
            ),
            if (_online)
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.public, size: 16, color: Tv.gold),
                    const SizedBox(width: 6),
                    Text('PARTIE EN LIGNE',
                        style: Tv.label(11, color: Tv.gold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          widget.tournament
                              ? 'Chacun joue ses matchs chez lui'
                              : widget.salon
                                  ? 'Chaque maison joue chez elle, sur sa cible'
                                  : 'Chacun joue chez soi sur sa cible ; '
                                      'les stats comptent comme une partie '
                                      'normale',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.label(11)),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                        _localTournament
                            ? 'PRÉPARE TON TOURNOI'
                            : 'PRÉPARE TA PARTIE',
                        style: Tv.title(16, color: Tv.text)),
                  ),
                  Expanded(child: _favBar()),
                ],
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SetupColumn(
                        title: 'Choisir le jeu',
                        children: [
                          if (!_fixed)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final (v, l) in [
                                    ('x01', '01'),
                                    ('cricket', 'CRICKET'),
                                    if (!_double) ('match', 'MEDLEY'),
                                    if (!widget.tournament && !_double) ...[
                                      ('practice', 'ENTRAÎN.'),
                                      ('party', 'PARTY'),
                                    ],
                                  ])
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      showCheckmark: false,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      labelPadding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      label: Text(l,
                                          style: Tv.title(15,
                                              color: _kind == v
                                                  ? Colors.black
                                                  : Tv.text)),
                                      selected: _kind == v,
                                      onSelected: (_) =>
                                          setState(() => _kind = v),
                                    ),
                                ],
                              ),
                            ),
                          if (_localTournament)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: TextField(
                                key: const ValueKey('tn-name'),
                                controller: _tnName,
                                maxLength: 40,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                    labelText: 'Nom du tournoi',
                                    hintText: 'Tournoi du samedi',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder()),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ..._gameItems(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SetupColumn(
                        title: 'Règles',
                        children: _ruleItems(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_online)
                      Expanded(child: _onlineColumn())
                    else
                      Expanded(
                        child: SetupColumn(
                          title: 'Joueurs (${_selected.length})',
                          children: [
                            if (_selected.isNotEmpty)
                              ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                onReorderItem: (from, to) => setState(() =>
                                    _selected.insert(
                                        to, _selected.removeAt(from))),
                                children: [
                                  for (var i = 0; i < _selected.length; i++)
                                    _playerTile(i, _selected[i]),
                                ],
                              ),
                            if (_selected.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
                                child:
                                    SetupNote('Aucun joueur pour l\'instant.'),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      key: const ValueKey('players-add'),
                                      onPressed: full ? null : _addSheet,
                                      icon: const Icon(Icons.person_add_alt_1,
                                          size: 20),
                                      label: Text(
                                          full
                                              ? 'COMPLET ($_maxPlayers MAX)'
                                              : 'AJOUTER',
                                          style: Tv.title(16)),
                                    ),
                                  ),
                                  if (_selected.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      key: const ValueKey('players-clear'),
                                      tooltip: 'Tout vider',
                                      onPressed: _clearPlayers,
                                      icon: const Icon(Icons.delete_sweep),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ─── Bandeau du bas : résumé, favori, lancer ───
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                border: Border(top: BorderSide(color: Tv.gold, width: 2)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_summary.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tv.title(18, color: Tv.gold)),
                        Text(
                            problem ??
                                (_online
                                    ? _onlineInfo
                                    : '${plural(_selected.length, 'joueur')}'
                                        '${first == null ? '' : ' · $first commence'}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: problem != null
                                ? Tv.title(13, color: Tv.red)
                                : Tv.label(12)),
                      ],
                    ),
                  ),
                  if (!_online) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('fav-add'),
                      onPressed: _addFavorite,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Tv.gold,
                          side: BorderSide(color: Tv.gold),
                          visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.star_border, size: 18),
                      label: const Text('FAVORI'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      key: widget.salon
                          ? const ValueKey('salon-pick')
                          : widget.tournament && _online
                              ? const ValueKey('tn-create')
                              : _online
                                  ? const ValueKey('online-challenge')
                                  : null,
                      onPressed: widget.tournament && _online
                          ? (_tnName.text.trim().isEmpty
                              ? null
                              : _createTournament)
                          : problem == null
                              ? _startGame
                              : null,
                      icon: Icon(widget.tournament && _online
                          ? Icons.account_tree
                          : widget.salon
                              ? Icons.check
                              : _online
                                  ? Icons.public
                                  : Icons.play_arrow),
                      label: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: _online ? 260 : 190),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              _localTournament
                                  ? 'CRÉER LE TOURNOI (${_selected.length})'
                                  : widget.tournament
                                      ? 'CRÉER : ${_gameName.toUpperCase()}'
                                      : widget.salon
                                          ? 'CHOISIR : ${_gameName.toUpperCase()}'
                                          : _online
                                              ? 'DÉFIER : ${_gameName.toUpperCase()}'
                                              : 'LANCER ${_gameName.toUpperCase()}',
                              style: Tv.title(20, color: Colors.black)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _tnName = TextEditingController();
  int _tnSize = 8;

  @override
  void dispose() {
    _tnName.dispose();
    super.dispose();
  }

  /// Création d'un tournoi : nom, nombre de places, bouton « Créer ».
  Future<void> _createTournament() async {
    await _save();
    if (!mounted) return;
    final DartsGame g = _matchOn
        ? MatchGame(_match, _order)
        : _cricketOn
            ? CricketGame(_cricket, _order)
            : X01Game(_settings, _order);
    Navigator.pop(context, {
      'game': g.toJson(),
      'label': _gameName,
      'name': _tnName.text.trim(),
      'size': _tnSize,
    });
  }

  /// Ligne d'information de la barre du bas (en ligne).
  String get _onlineInfo {
    if (widget.tournament) {
      return 'Élimination directe · $_tnSize places';
    }
    if (widget.salon) {
      return '${plural(widget.online!.length, 'joueur')} · '
          '${_first == 2 ? 'ordre au hasard' : 'maisons en alternance'}';
    }
    final opp = widget.online![1].name;
    return '${_double ? 'En double' : '1 contre 1'} · '
        '${_first == 0 ? 'je commence' : _first == 1 ? '$opp commence' : 'qui commence au hasard'}';
  }

  /// 3e colonne en ligne : adversaire (défi), joueurs (salon) ou tournoi.
  Widget _onlineColumn() {
    if (widget.tournament) {
      return SetupColumn(
        title: 'Tournoi',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: TextField(
              key: const ValueKey('tn-name'),
              controller: _tnName,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nom du tournoi',
                  hintText: 'Coupe du vendredi',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SetupPick<int>(
              label: 'Places',
              value: _tnSize,
              values: const [4, 8, 16],
              text: (n) => '$n',
              onChanged: (v) => setState(() => _tnSize = v)),
          const SetupNote(
              'Élimination directe, en ligne : chacun joue ses matchs chez '
              'lui. Tu lances le tournoi quand tout le monde est inscrit ; '
              's\'il manque des joueurs, certains passent le 1er tour sans '
              'jouer. Qui commence est tiré au sort.'),
        ],
      );
    }
    Widget first(List<(int, String)> options) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (v, l) in options)
                ChoiceChip(
                  key: ValueKey('first-$v'),
                  label: Text(l.toUpperCase()),
                  selected: _first == v,
                  onSelected: (_) => setState(() => _first = v),
                ),
            ],
          ),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(t.toUpperCase(), style: Tv.label(12, color: Tv.gold)),
        );
    if (widget.salon) {
      final players = widget.online!;
      return SetupColumn(
        title: 'Joueurs du salon (${players.length})',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in players)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: PlayerAvatar(
                        name: p.name,
                        color: store.colorOf(p.id),
                        size: 22,
                        id: p.id),
                    label: Text(p.name),
                  ),
              ],
            ),
          ),
          label('Ordre'),
          first(const [(0, 'Maisons en alternance'), (2, 'Au hasard')]),
          const SetupNote('Chaque maison joue chez elle, sur sa cible, pour '
              'ses joueurs. Les joueurs qui changent dans le salon sont '
              'repris au lancement.'),
        ],
      );
    }
    final me = widget.online![0];
    final opp = widget.online![1];
    final mate = _double ? widget.online![2] : null;
    final size = _double ? 32.0 : 52.0;
    Widget who(X01Player? p) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p == null)
              CircleAvatar(
                  radius: size / 2,
                  backgroundColor: Tv.panel2,
                  child: Icon(Icons.help_outline, color: Tv.muted))
            else
              PlayerAvatar(
                  name: p.name,
                  color: store.colorOf(p.id),
                  size: size,
                  id: p.id),
            const SizedBox(height: 4),
            Text(p == null ? 'ÉQUIPIER' : p.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p == null ? Tv.label(10) : Tv.title(_double ? 13 : 16)),
          ],
        );
    return SetupColumn(
      title: _double ? 'Adversaires' : 'Adversaire',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          child: Row(
            children: [
              Expanded(child: who(me)),
              if (_double) Expanded(child: who(mate)),
              Text('VS', style: Tv.title(_double ? 18 : 24, color: Tv.gold)),
              Expanded(child: who(opp)),
              if (_double) Expanded(child: who(null)),
            ],
          ),
        ),
        label('Qui commence'),
        first([(0, 'Moi'), (1, opp.name), (2, 'Au hasard')]),
        SetupNote(_double
            ? 'Chaque équipe joue chez elle sur sa cible. ${opp.name} '
                'choisit son équipier en acceptant. 01 : score commun à '
                'l\'équipe.'
            : 'Chacun joue chez soi sur sa cible. Les stats comptent comme '
                'une partie normale.'),
      ],
    );
  }

  Widget _playerTile(int index, String id) {
    final guest = isGuestId(id);
    final p = store.byId(id);
    final name = _nameOf(id);
    return ListTile(
      key: ValueKey(id),
      dense: true,
      // Colonne étroite : marges réduites
      contentPadding: const EdgeInsets.only(left: 10, right: 2),
      horizontalTitleGap: 6,
      minLeadingWidth: 0,
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
      title: Row(
        children: [
          PlayerAvatar(
              id: p?.key ?? id,
              name: name,
              color: p?.color ?? kGuestColor,
              size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis, style: Tv.title(18)),
          ),
          // Étiquettes : rognées quand la colonne est étroite (équipes)
          // (le joueur virtuel a déjà son avatar robot)
          if (guest && !isBotId(id))
            Flexible(
              child: Text('  INVITÉ',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: Tv.label(10)),
            ),
          if (p?.expired == true)
            Flexible(
              child: Text('  À RECONNECTER',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: Tv.label(10, color: Tv.red)),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_teams)
            SizedBox(
              width: 88,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                segments: [
                  for (var t = 0; t < 2; t++)
                    ButtonSegment(
                      value: t,
                      label: Text(kTeamNames[t].split(' ').last,
                          style: TextStyle(
                              color: kTeamColors[t],
                              fontWeight: FontWeight.bold)),
                    ),
                ],
                selected: {_teamOf(id)},
                onSelectionChanged: (s) => setState(() => _team[id] = s.first),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selected.remove(id)),
          ),
        ],
      ),
    );
  }
}
