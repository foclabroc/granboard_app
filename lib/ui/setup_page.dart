import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../board_service.dart';
import '../game/x01.dart';
import '../players.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets.dart';

const _prefKey = 'x01_setup_v1';
const _maxPlayers = 8;
const _limits = <int?>[null, 10, 15, 20, 25, 30];
const kTeamNames = ['Équipe A', 'Équipe B'];
const kTeamColors = [Color(0xFFE53935), Color(0xFF1E88E5)];

/// Réglages d'une partie X01 / Freeze.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

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
  final List<String> _selected = [];
  final Map<String, int> _team = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        _selected
          ..clear()
          ..addAll([
            for (final id in (j['players'] as List? ?? const []))
              if (store.byId(id as String) != null) id
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
        freeze: _freeze,
      );

  int _teamOf(String id) => _team[id] ?? 0;

  /// Joueurs dans l'ordre de lancer (Freeze : équipes en alternance).
  List<X01Player> get _order {
    X01Player mk(String id, int team) =>
        X01Player(id: id, name: store.byId(id)!.name, team: team);
    if (!_freeze) {
      return [for (var i = 0; i < _selected.length; i++) mk(_selected[i], i)];
    }
    final a = _selected.where((id) => _teamOf(id) == 0).toList();
    final b = _selected.where((id) => _teamOf(id) == 1).toList();
    return [
      for (var i = 0; i < a.length; i++) ...[mk(a[i], 0), mk(b[i], 1)]
    ];
  }

  String? get _problem {
    if (_selected.isEmpty) return 'Ajoute au moins un joueur';
    if (_freeze) {
      final a = _selected.where((id) => _teamOf(id) == 0).length;
      final b = _selected.length - a;
      if (a == 0 || b == 0) return 'Le Freeze se joue à 2 équipes';
      if (a != b) return 'Les 2 équipes doivent avoir autant de joueurs';
    }
    return null;
  }

  Future<void> _newPlayer() async {
    final name = await askName(context);
    if (name == null) return;
    final p = await store.add(name);
    if (_selected.length < _maxPlayers) _select(p.id);
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
    if (!BoardService.instance.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cible non connectée : connecte-la pour jouer')));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => GamePage(settings: _settings, players: _order)),
    );
  }

  Widget _section(String title) => TvSection(title);

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final available =
        store.players.where((p) => !_selected.contains(p.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('NOUVELLE PARTIE')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _section('Mode'),
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
          SwitchListTile(
            title: const Text('Freeze (équipes)'),
            subtitle:
                const Text('Une équipe dont le total restant dépasse celui de '
                    'l\'adversaire est gelée ❄ et ne peut pas finir.'),
            value: _freeze,
            onChanged: (v) => setState(() => _freeze = v),
          ),
          _section('Règles'),
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
          ListTile(
            title: const Text('Limite de manches'),
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
          _section(
              'Joueurs ${_selected.length}/$_maxPlayers · ordre de lancer'),
          if (_selected.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) => setState(
                  () => _selected.insert(to, _selected.removeAt(from))),
              children: [
                for (var i = 0; i < _selected.length; i++)
                  _playerTile(i, _selected[i]),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selected.length < _maxPlayers)
                  for (final p in available)
                    ActionChip(
                      avatar: PlayerAvatar.of(p, size: 24),
                      label: Text(p.name),
                      onPressed: () => _select(p.id),
                    ),
                ActionChip(
                  avatar: const Icon(Icons.person_add, size: 18),
                  label: const Text('Nouveau joueur'),
                  onPressed: _newPlayer,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(problem,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: problem == null ? _startGame : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text('LANCER ${_settings.name.toUpperCase()}',
                      style: Tv.title(22, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerTile(int index, String id) {
    final p = store.byId(id)!;
    return ListTile(
      key: ValueKey(id),
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
      title: Row(
        children: [
          PlayerAvatar.of(p, size: 28),
          const SizedBox(width: 10),
          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_freeze)
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
