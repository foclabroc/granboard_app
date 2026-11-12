import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../board_service.dart';
import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import '../players.dart';
import 'account_page.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets.dart';

const kSetupPrefKey = 'x01_setup_v1';
const _prefKey = kSetupPrefKey;
const _maxPlayers = 8;
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
  const SetupPage({super.key, this.kind, this.online});

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

  /// En ligne, qui commence : 0 moi, 1 l'adversaire, 2 au hasard.
  int _first = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.kind != null) setState(() => _kind = widget.kind!);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _start = j['start'] as int? ?? 501;
        _freeze = j['freeze'] as bool? ?? false;
        _in = InRule.values[j['in'] as int? ?? 0];
        _out = OutRule.values[j['out'] as int? ?? 1];
        _bull = BullMode.values[j['bull'] as int? ?? 0];
        _limit = j['limit'] as int?;
        _kind = widget.kind ?? j['kind'] as String? ?? 'x01';
        _variant = CricketVariant.values.firstWhere(
            (v) => v.name == j['variant'],
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
            LegKind.values
                .firstWhere((x) => x.name == k, orElse: () => LegKind.x01)
        ];
        _mPattern = [
          for (var i = 0; i < 13; i++)
            i < mp.length ? mp[i] : MatchSettings.alternate(13)[i]
        ];
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
  bool get _teams => _matchOn || _practiceOn || _online
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

  int _teamOf(String id) => _team[id] ?? 0;

  String _nameOf(String id) =>
      isGuestId(id) ? 'Invité ${id.substring(6)}' : store.byId(id)?.name ?? '?';

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

    return Scaffold(
      appBar: AppBar(
          title: Text(_online
              ? 'DÉFIER ${widget.online!.last.name.toUpperCase()}'
              : 'NOUVELLE PARTIE')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Mode et règles ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                const TvSection('Jeu',
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    segments: [
                      for (final (v, l) in const [
                        ('x01', '01'),
                        ('cricket', 'CRICKET'),
                        ('match', 'MATCH'),
                        ('practice', 'ENTRAÎN.'),
                        ('party', 'FÊTE'),
                      ])
                        ButtonSegment(
                            value: v,
                            label: FittedBox(
                                fit: BoxFit.scaleDown, child: Text(l))),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (v) => setState(() => _kind = v.first),
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
          if (_online)
            Expanded(child: _onlinePanel(problem))
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        TvSection(
                            'Joueurs ${_selected.length}/$_maxPlayers · ordre de lancer',
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
                                    avatar: PlayerAvatar.of(p, size: 24),
                                    label: Text(
                                        p.expired ? '${p.name} ⚠' : p.name),
                                    onPressed: () => _select(p.key),
                                  ),
                              if (!full)
                                ActionChip(
                                  avatar: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('Invité'),
                                  onPressed: _addGuest,
                                ),
                              ActionChip(
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
                              'Les invités jouent sans enregistrer de stats.',
                              style: Tv.label(12)),
                        ),
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
                              child: Text(problem,
                                  style: Tv.title(15, color: Tv.red)),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: problem == null ? _startGame : null,
                              icon: const Icon(Icons.play_arrow),
                              label: Text('LANCER ${_gameName.toUpperCase()}',
                                  style: Tv.title(22, color: Colors.black)),
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
        if (!match && !_online)
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
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
      title: Row(
        children: [
          PlayerAvatar(
              id: p?.key, name: name, color: p?.color ?? kGuestColor, size: 28),
          const SizedBox(width: 10),
          Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis, style: Tv.title(18)),
          ),
          if (guest) Text('  INVITÉ', style: Tv.label(10)),
          if (p?.expired == true)
            Text('  À RECONNECTER', style: Tv.label(10, color: Tv.red)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_teams)
            SegmentedButton<int>(
              showSelectedIcon: false,
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
