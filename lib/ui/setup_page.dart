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

  /// Défi en ligne : moi puis l'adversaire. La page ne lance pas la partie,
  /// elle renvoie son JSON (`Navigator.pop`) pour l'envoyer avec le défi.
  final List<X01Player>? online;

  /// Création d'un tournoi (avec [online] = moi + un adversaire fictif) :
  /// 01 / Cricket / Match seulement, nom et taille du tableau ; renvoie
  /// {game, label, name, size}.
  final bool tournament;
  const SetupPage({super.key, this.kind, this.online, this.tournament = false});

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
  final List<String> _selected = [];
  final Map<String, int> _team = {};

  bool get _online => widget.online != null;

  /// Ouvert depuis une tuile de l'accueil : le choix du jeu est masqué.
  bool get _fixed => widget.kind != null && !_online;

  String get _familyName => switch (_kind) {
        'cricket' => 'CRICKET',
        'match' => 'MATCH',
        'practice' => 'ENTRAÎNEMENT',
        'party' => 'FÊTE',
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
    final raw = prefs.getString(_prefKey);
    if (raw == null) return _selectOwner();
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
      );

  CricketSettings get _cricket => CricketSettings(
        variant: _variant,
        teams: _cTeams && !_online,
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
          ? 'Match $_mLegs legs'
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
    return [
      for (var i = 0; i < a.length; i++) ...[mk(a[i], 0), mk(b[i], 1)]
    ];
  }

  String? get _problem {
    final n = _online ? 2 : _selected.length;
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
      Navigator.pop(context, g.toJson());
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
  Widget build(BuildContext context) {
    final problem = _problem;
    final available =
        store.players.where((p) => !_selected.contains(p.key)).toList();
    final full = _selected.length >= _maxPlayers;
    final short = MediaQuery.sizeOf(context).height < 380;
    final chipDensity = short ? VisualDensity.compact : null;
    if (!_online) return _broadcast(problem, available, full, chipDensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament
            ? (_online ? 'NOUVEAU TOURNOI EN LIGNE' : 'TOURNOI À LA MAISON')
            : _online
                ? 'DÉFIER ${widget.online!.last.name.toUpperCase()}'
                : _fixed
                    ? _familyName
                    : 'NOUVELLE PARTIE'),
        actions: [
          if (_fixed) ...[
            RulesButton(title: _gameName, text: _rulesText),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Mode et règles ───
          Expanded(
            flex: _online ? 1 : 5,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (_localTournament)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: TextField(
                      key: const ValueKey('tn-name'),
                      controller: _tnName,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Nom du tournoi',
                          hintText: 'Tournoi du samedi',
                          counterText: '',
                          isDense: true,
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                // Ouvert depuis une tuile de l'accueil : ce jeu seulement
                if (!_fixed)
                  Row(
                    children: [
                      const Expanded(
                        child: TvSection('Jeu',
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 8)),
                      ),
                      RulesButton(title: _gameName, text: _rulesText),
                      const SizedBox(width: 8),
                    ],
                  ),
                if (!_fixed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4)),
                      segments: [
                        for (final (v, l) in [
                          ('x01', '01'),
                          ('cricket', 'CRICKET'),
                          ('match', 'MATCH'),
                          if (!widget.tournament) ...[
                            ('practice', 'ENTRAÎN.'),
                            ('party', 'FÊTE'),
                          ],
                        ])
                          ButtonSegment(
                              value: v,
                              label: FittedBox(
                                  fit: BoxFit.scaleDown, child: Text(l))),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (v) =>
                          setState(() => _kind = v.first),
                    ),
                  ),
                if (_practiceOn)
                  ..._practiceOptions()
                else if (_matchOn)
                  ..._matchOptions()
                else if (_cricketOn)
                  ..._cricketOptions()
                else
                  ..._x01Options(),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // ─── Joueurs ───
          if (widget.tournament && _online)
            Expanded(child: _tournamentPanel())
          else if (_online)
            Expanded(child: _onlinePanel(problem))
          else
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        TvSection('Joueurs ${_selected.length}/$_maxPlayers',
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6)),
                        if (_selected.isNotEmpty)
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorderItem: (from, to) => setState(() =>
                                _selected.insert(to, _selected.removeAt(from))),
                            children: [
                              for (var i = 0; i < _selected.length; i++)
                                _playerTile(i, _selected[i]),
                            ],
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (!full)
                                for (final p in available)
                                  ActionChip(
                                    visualDensity: chipDensity,
                                    avatar: PlayerAvatar.of(p, size: 24),
                                    label: Text(
                                        p.expired ? '${p.name} ⚠' : p.name),
                                    onPressed: () => _select(p.key),
                                  ),
                              if (!full)
                                ActionChip(
                                  visualDensity: chipDensity,
                                  avatar: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('Invité'),
                                  onPressed: _addGuest,
                                ),
                              if (!full)
                                ActionChip(
                                  key: const ValueKey('add-bot'),
                                  visualDensity: chipDensity,
                                  avatar: const Icon(Icons.smart_toy_outlined,
                                      size: 18),
                                  label: const Text('Joueur virtuel'),
                                  onPressed: _addBot,
                                ),
                              ActionChip(
                                visualDensity: chipDensity,
                                avatar: const Icon(Icons.person_add, size: 18),
                                label: const Text('Ajouter un joueur'),
                                onPressed: _newPlayer,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                              'Les invités et les bots jouent sans enregistrer de stats. '
                              'Le bot prend le niveau de ses adversaires.',
                              style: Tv.label(12)),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    left: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, short ? 6 : 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (problem != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(problem,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style:
                                      Tv.title(short ? 13 : 15, color: Tv.red)),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: short ? 44 : 54,
                            child: FilledButton.icon(
                              onPressed: problem == null ? _startGame : null,
                              icon: const Icon(Icons.play_arrow),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    _localTournament
                                        ? 'CRÉER LE TOURNOI (${_selected.length})'
                                        : 'LANCER ${_gameName.toUpperCase()}',
                                    style: Tv.title(22, color: Colors.black)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
    if (_matchOn) return 'Match $_mLegs legs · $_start ${_out.label}';
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
      if (!widget.tournament)
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
              label: 'Objectif',
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
        if (!widget.tournament)
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
          SetupItem(
            label: 'Leg ${i + 1}',
            value: _mPattern[i] == LegKind.x01 ? '$_start' : 'Cricket',
            onTap: () => setState(() => _mPattern[i] =
                _mPattern[i] == LegKind.x01 ? LegKind.cricket : LegKind.x01),
          ),
        const SetupNote(
            'Touche un leg pour passer de 01 à Cricket et inversement. '
            'Cricket : règles Standard, 20 manches.'),
        SetupPick<int>(
            label: 'Legs 01',
            value: _start,
            values: kStartScores,
            text: (n) => '$n',
            onChanged: (v) => setState(() => _start = v)),
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
      if (_freeze && !widget.tournament)
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
                  : _fixed
                      ? _familyName
                      : 'Nouvelle partie',
              sub: 'Configuration',
              actions: [RulesButton(title: _gameName, text: _rulesText)],
            ),
            _favBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SetupColumn(
                        title: _practiceOn
                            ? 'Jeu (${_gameItems().length})'
                            : _cricketOn
                                ? 'Variante'
                                : _matchOn
                                    ? 'Legs'
                                    : 'Jeu',
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
                                    ('match', 'MATCH'),
                                    if (!widget.tournament) ...[
                                      ('practice', 'ENTRAÎN.'),
                                      ('party', 'FÊTE'),
                                    ],
                                  ])
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(l),
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
                        title: _practiceOn ? 'Réglages' : 'Règles',
                        children: _ruleItems(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SetupColumn(
                        title: 'Joueurs ${_selected.length}/$_maxPlayers',
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
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (!full)
                                for (final p in available)
                                  ActionChip(
                                    visualDensity: chipDensity,
                                    avatar: PlayerAvatar.of(p, size: 22),
                                    label: Text(
                                        p.expired ? '${p.name} ⚠' : p.name),
                                    onPressed: () => _select(p.key),
                                  ),
                              if (!full)
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('Invité'),
                                  onPressed: _addGuest,
                                ),
                              if (!full)
                                ActionChip(
                                  key: const ValueKey('add-bot'),
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.smart_toy_outlined,
                                      size: 18),
                                  label: const Text('Joueur virtuel'),
                                  onPressed: _addBot,
                                ),
                              ActionChip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.person_add, size: 18),
                                label: const Text('Ajouter un joueur'),
                                onPressed: _newPlayer,
                              ),
                            ],
                          ),
                          const SetupNote('Invités et bots jouent sans '
                              'stats. Le bot prend le niveau de ses '
                              'adversaires.'),
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
                                '${plural(_selected.length, 'joueur')}'
                                    '${first == null ? '' : ' · $first commence'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: problem != null
                                ? Tv.title(13, color: Tv.red)
                                : Tv.label(12)),
                      ],
                    ),
                  ),
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
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: problem == null ? _startGame : null,
                      icon: const Icon(Icons.play_arrow),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              _localTournament
                                  ? 'CRÉER LE TOURNOI (${_selected.length})'
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
  Widget _tournamentPanel() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            children: [
              const TvSection('Tournoi', padding: EdgeInsets.zero),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('tn-name'),
                controller: _tnName,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nom du tournoi',
                    hintText: 'Coupe du vendredi',
                    counterText: '',
                    border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const TvSection('Places', padding: EdgeInsets.zero),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 4, label: Text('4')),
                  ButtonSegment(value: 8, label: Text('8')),
                  ButtonSegment(value: 16, label: Text('16')),
                ],
                selected: {_tnSize},
                onSelectionChanged: (v) => setState(() => _tnSize = v.first),
              ),
              const SizedBox(height: 10),
              Text(
                  'Élimination directe, en ligne : chacun joue ses matchs '
                  'chez lui. Tu lances le tournoi quand tout le monde est '
                  'inscrit ; s\'il manque des joueurs, certains passent le '
                  '1er tour sans jouer. Qui commence est tiré au sort.',
                  style: Tv.label(12)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          left: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                key: const ValueKey('tn-create'),
                onPressed:
                    _tnName.text.trim().isEmpty ? null : _createTournament,
                icon: const Icon(Icons.account_tree),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('CRÉER : ${_gameName.toUpperCase()}',
                      style: Tv.title(22, color: Colors.black)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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

  /// Défi en ligne : l'adversaire, qui commence, bouton « Défier ».
  Widget _onlinePanel(String? problem) {
    final me = widget.online!.first;
    final opp = widget.online!.last;
    Widget who(X01Player p) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(
                name: p.name, color: store.colorOf(p.id), size: 54, id: p.id),
            const SizedBox(height: 4),
            Text(p.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.title(18)),
          ],
        );
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            children: [
              const TvSection('Partie en ligne', padding: EdgeInsets.zero),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: who(me)),
                  Text('VS', style: Tv.title(26, color: Tv.gold)),
                  Expanded(child: who(opp)),
                ],
              ),
              const SizedBox(height: 14),
              const TvSection('Qui commence', padding: EdgeInsets.zero),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: 0, label: Text('MOI')),
                  ButtonSegment(
                      value: 1,
                      label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(opp.name.toUpperCase()))),
                  const ButtonSegment(value: 2, label: Text('AU HASARD')),
                ],
                selected: {_first},
                onSelectionChanged: (v) => setState(() => _first = v.first),
              ),
              const SizedBox(height: 10),
              Text(
                  'Chacun joue chez soi sur sa cible. Les stats comptent '
                  'comme une partie normale.',
                  style: Tv.label(12)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          left: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(problem, style: Tv.title(15, color: Tv.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: problem == null ? _startGame : null,
                    icon: const Icon(Icons.public),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('DÉFIER : ${_gameName.toUpperCase()}',
                          style: Tv.title(22, color: Colors.black)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _practiceOptions() {
    final info = _pInfo;
    final rounds = _pRounds ?? info.defaultRounds;
    final goal = _pGoal ?? info.defaultGoal;
    return [
      TvSection(_partyOn ? 'Jeu de fête' : 'Jeu d\'entraînement',
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in PracticeKind.values)
              if (kPracticeInfo[k]!.party == _partyOn)
                ChoiceChip(
                  label: Text(kPracticeInfo[k]!.name.toUpperCase()),
                  selected: _curKind == k,
                  onSelected: (_) => setState(() {
                    _curKind = k;
                    _pRounds = null;
                    _pGoal = null;
                  }),
                ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(info.help, style: Tv.label(12, color: Tv.text)),
      ),
      if (info.goals != null)
        ListTile(
          title: Text('Objectif', style: Tv.title(17)),
          trailing: DropdownButton<int>(
            value: goal,
            items: [
              for (final n in info.goals!)
                DropdownMenuItem(
                    value: n, child: Text(n == 0 ? 'En 10 manches' : '$n')),
            ],
            onChanged: (v) => setState(() => _pGoal = v),
          ),
        ),
      if (info.rounds != null)
        ListTile(
          title: Text(
              _curKind == PracticeKind.checkout121
                  ? 'Fléchettes par tentative'
                  : 'Manches',
              style: Tv.title(17)),
          trailing: DropdownButton<int>(
            value: rounds,
            items: [
              for (final n in info.rounds!)
                DropdownMenuItem(
                    value: n,
                    child: Text(_curKind == PracticeKind.countUp && n == 33
                        ? '33 (99 fléchettes)'
                        : '$n')),
            ],
            onChanged: (v) => setState(() => _pRounds = v),
          ),
        ),
      if (info.target)
        ListTile(
          title: Text('Cible', style: Tv.title(17)),
          trailing: DropdownButton<int>(
            value: _pTarget,
            items: [
              for (final n in [for (var i = 20; i >= 1; i--) i, 25])
                DropdownMenuItem(
                    value: n, child: Text(n == 25 ? 'Bull' : '$n')),
            ],
            onChanged: (v) => setState(() => _pTarget = v ?? 20),
          ),
        ),
      for (final o in info.options.entries)
        SwitchListTile(
          title: Text(o.value, style: Tv.title(17)),
          value: _pOptions.contains(o.key),
          onChanged: (v) => setState(() {
            // Options qui s'excluent (doubles / triples seulement)
            if (v && (o.key == 'double' || o.key == 'triple')) {
              _pOptions.removeAll({'double', 'triple'});
            }
            v ? _pOptions.add(o.key) : _pOptions.remove(o.key);
          }),
        ),
      if (info.bull)
        _RuleRow<BullMode>(
          label: 'Bull',
          value: _bull,
          values: BullMode.values,
          text: (b) => b == BullMode.split ? '25 / 50' : '50 / 50',
          onChanged: (v) => setState(() => _bull = v),
        ),
    ];
  }

  List<Widget> _matchOptions() => [
        const TvSection('Nombre de legs',
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in kMatchLegs)
                ChoiceChip(
                  label: Text('$n',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  selected: _mLegs == n,
                  onSelected: (_) => setState(() => _mLegs = n),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
              'Le premier à ${_mLegs ~/ 2 + 1} legs gagne. Le joueur qui '
              'commence change à chaque leg.',
              style: Tv.label(12, color: Tv.text)),
        ),
        const TvSection('Jeu de chaque leg (touche pour changer)',
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _mLegs; i++)
                ActionChip(
                  avatar: CircleAvatar(
                      backgroundColor: Tv.panel2,
                      child: Text('${i + 1}', style: Tv.label(11))),
                  label: Text(
                      _mPattern[i] == LegKind.x01 ? '$_start' : 'CRICKET',
                      style: Tv.title(15,
                          color: _mPattern[i] == LegKind.x01
                              ? Tv.goldLight
                              : Tv.green)),
                  onPressed: () => setState(() => _mPattern[i] =
                      _mPattern[i] == LegKind.x01
                          ? LegKind.cricket
                          : LegKind.x01),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Cricket : règles Standard, 20 manches.',
              style: Tv.label(12)),
        ),
        ..._x01Options(match: true),
      ];

  List<Widget> _x01Options({bool match = false}) => [
        TvSection(match ? 'Legs 01' : 'Mode',
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final s in kStartScores)
                ChoiceChip(
                  label: Text('$s',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  selected: _start == s,
                  onSelected: (_) => setState(() => _start = s),
                ),
            ],
          ),
        ),
        if (!match && !_online && !widget.tournament)
          SwitchListTile(
            title: Text('Freeze (équipes)', style: Tv.title(18)),
            subtitle:
                const Text('Une équipe dont le total restant dépasse celui de '
                    'l\'adversaire est gelée ❄ et ne peut pas finir.'),
            value: _freeze,
            onChanged: (v) => setState(() => _freeze = v),
          ),
        const TvSection('Règles', padding: EdgeInsets.fromLTRB(16, 8, 16, 6)),
        _RuleRow<InRule>(
          label: 'Début',
          value: _in,
          values: InRule.values,
          text: (r) => r.label.split(' ').first,
          onChanged: (v) => setState(() => _in = v),
        ),
        _RuleRow<OutRule>(
          label: 'Fin',
          value: _out,
          values: OutRule.values,
          text: (r) => r.label.split(' ').first,
          onChanged: (v) => setState(() => _out = v),
        ),
        _RuleRow<BullMode>(
          label: 'Bull',
          value: _bull,
          values: BullMode.values,
          text: (b) => b == BullMode.split ? '25 / 50' : '50 / 50',
          onChanged: (v) => setState(() => _bull = v),
        ),
        if (!match)
          ListTile(
            title: Text('Limite de manches', style: Tv.title(17)),
            trailing: DropdownButton<int?>(
              value: _limit,
              items: [
                for (final l in _limits)
                  DropdownMenuItem(
                      value: l, child: Text(l == null ? 'Aucune' : '$l')),
              ],
              onChanged: (v) => setState(() => _limit = v),
            ),
          ),
      ];

  List<Widget> _cricketOptions() => [
        const TvSection('Variante', padding: EdgeInsets.fromLTRB(16, 8, 16, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in CricketVariant.values)
                ChoiceChip(
                  label: Text(v.label.toUpperCase()),
                  selected: _variant == v,
                  onSelected: (_) => setState(() => _variant = v),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(_variant.help, style: Tv.label(12, color: Tv.text)),
        ),
        if (!_online)
          SwitchListTile(
            title: Text('Équipes (Team Cricket)', style: Tv.title(18)),
            subtitle: const Text(
                'Marques et points communs à l\'équipe, joueurs en alternance.'),
            value: _cTeams,
            onChanged: (v) => setState(() => _cTeams = v),
          ),
        ListTile(
          title: Text('Limite de manches', style: Tv.title(17)),
          subtitle: const Text('À la limite, le meilleur score gagne'),
          trailing: DropdownButton<int?>(
            value: _cLimit,
            items: [
              for (final l in kCricketRoundLimits)
                DropdownMenuItem(
                    value: l, child: Text(l == null ? 'Aucune' : '$l')),
            ],
            onChanged: (v) => setState(() => _cLimit = v),
          ),
        ),
      ];

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
          if (guest)
            Text(isBotId(id) ? '  VIRTUEL' : '  INVITÉ', style: Tv.label(10)),
          if (p?.expired == true)
            Text('  À RECONNECTER', style: Tv.label(10, color: Tv.red)),
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

class _RuleRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) text;
  final ValueChanged<T> onChanged;
  const _RuleRow(
      {required this.label,
      required this.value,
      required this.values,
      required this.text,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label)),
          Expanded(
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final v in values)
                  ButtonSegment(value: v, label: Text(text(v))),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
