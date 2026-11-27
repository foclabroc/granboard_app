import 'dart:async';

import 'package:flutter/material.dart';

import '../game/x01.dart';
import '../media.dart';
import '../online/online.dart';
import '../players.dart';
import '../server.dart';
import '../tournament.dart';
import '../tv_link.dart';
import '../game/darts_game.dart';
import 'game_page.dart';
import 'online_page.dart' show waitForAnswer;
import 'setup_page.dart';
import 'setup_widgets.dart';
import 'stats_page.dart' show openPlayerStats;
import 'game_theme.dart';
import 'theme.dart';
import 'widgets.dart';

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

String _err(Object e) => e is ApiError ? e.message : 'Erreur : $e';

/// Tuile « Tournois » : tournois ouverts, en cours, terminés ; création.
class TournamentsPage extends StatefulWidget {
  const TournamentsPage({super.key});

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  List<TnSummary>? _list;
  String? _error;
  bool _online = false;

  PlayerProfile? get _me => OnlineService.instance.me;
  final _local = LocalTournamentStore.instance;

  @override
  void initState() {
    super.initState();
    _local.load();
    _load();
  }

  /// Tournoi à la maison : joueurs du téléphone (comptes + invités), matchs
  /// sur cette cible.
  Future<void> _createLocal() async {
    final r = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SetupPage(tournament: true)),
    );
    if (r == null || !mounted) return;
    final t = LocalTournament.create(
      name: r['name'] as String,
      label: r['label'] as String,
      game: Map<String, dynamic>.from(r['game'] as Map),
      players: [
        for (final p in r['players'] as List)
          X01Player.fromJson(Map<String, dynamic>.from(p as Map))
      ],
    );
    await _local.add(t);
    if (mounted) _openLocal(t.uid);
  }

  Future<void> _openLocal(String uid) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => LocalTournamentPage(uid: uid)));
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final me = _me;
    if (me == null) return;
    try {
      final l = await TournamentApi.list(me.token);
      if (mounted) {
        setState(() {
          _list = l;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  Future<void> _open(int id) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => TournamentPage(id: id)));
    _load();
  }

  Future<void> _create() async {
    final me = _me;
    if (me == null) return;
    final r = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupPage(
          tournament: true,
          online: [
            X01Player(id: me.key, name: me.name),
            const X01Player(id: '0', name: 'Adversaire'),
          ],
        ),
      ),
    );
    if (r == null || !mounted) return;
    try {
      final id = await TournamentApi.create(me.token,
          name: r['name'] as String,
          size: r['size'] as int,
          label: r['label'] as String,
          game: Map<String, dynamic>.from(r['game'] as Map));
      if (mounted) _open(id);
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    }
  }

  @override
  Widget build(BuildContext context) => GameThemeScope(
      skin: GameSkins.tournament, child: Builder(builder: _menuBuild));

  Widget _menuBuild(BuildContext context) {
    final me = _me;
    return Scaffold(
      body: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            SetupBand(
              title: 'Tournois',
              sub: 'Configuration',
              actions: [
                if (_online && me != null)
                  IconButton(
                    key: const ValueKey('tn-refresh'),
                    tooltip: 'Actualiser',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            Expanded(
                child: SidePad(
              child: ListenableBuilder(
                listenable: _local,
                builder: (context, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _tab('À LA MAISON', false, Icons.home),
                                const SizedBox(width: 6),
                                _tab('EN LIGNE', true, Icons.public),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            key: ValueKey(_online ? 'tn-new' : 'tn-new-local'),
                            onPressed: _online
                                ? (me == null ? null : _create)
                                : _createLocal,
                            icon: const Icon(Icons.add, size: 19),
                            label: const Text('CRÉER UN TOURNOI'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _online ? _onlineList(me) : _localList(me)),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool online, IconData icon) {
    final selected = _online == online;
    return Flexible(
      child: TextButton.icon(
        key: ValueKey(online ? 'tn-tab-online' : 'tn-tab-local'),
        onPressed: () => setState(() => _online = online),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Tv.gold : Tv.muted,
          backgroundColor: selected ? Tv.panel2 : Colors.transparent,
          side: BorderSide(color: selected ? Tv.gold : Tv.line),
        ),
        icon: Icon(icon, size: 17),
        label: FittedBox(child: Text(label)),
      ),
    );
  }

  Widget _localList(PlayerProfile? me) {
    LocalTournament? nextTournament;
    TnMatch? next;
    Tournament? bracket;
    if (me != null) {
      for (final local in _local.list) {
        final t = local.view();
        final players = t.players.where((p) => p.key == me.key);
        if (players.isEmpty) continue;
        final match = t.myMatch(players.first.id);
        if (match != null) {
          nextTournament = local;
          bracket = t;
          next = match;
          break;
        }
      }
    }
    final selectedTournament = nextTournament;
    final selectedBracket = bracket;
    final selectedMatch = next;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        if (selectedTournament != null &&
            selectedBracket != null &&
            selectedMatch != null)
          _NextLocalMatch(
            tournament: selectedBracket,
            match: selectedMatch,
            onTap: () => _openLocal(selectedTournament.uid),
          ),
        if (_local.list.isEmpty)
          _empty('Aucun tournoi à la maison pour l’instant.\nCrée le premier !')
        else
          _cards([
            for (final lt in _local.list)
              _TournamentCard.local(lt, onTap: () => _openLocal(lt.uid)),
          ]),
      ],
    );
  }

  Widget _empty(String message) => Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Tv.title(18, color: Tv.text),
          ),
        ),
      );

  Widget _cards(List<Widget> cards) => LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 700 ? 2 : 1;
          const gap = 10.0;
          final width = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          );
        },
      );

  Widget _onlineList(PlayerProfile? me) {
    return me == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Crée ton profil (Joueurs) pour jouer les tournois en ligne.',
                textAlign: TextAlign.center,
                style: Tv.title(18, color: Tv.text),
              ),
            ),
          )
        : _list == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: Tv.title(16, color: Tv.red)),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('RÉESSAYER'),
                          ),
                        ],
                      ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: [
                    if (_error != null)
                      Text(_error!, style: Tv.title(16, color: Tv.red)),
                    if (_list!.isEmpty)
                      _empty(
                          'Aucun tournoi pour l\'instant :\ncrée le premier !')
                    else
                      _cards([
                        for (final t in _list!)
                          _TournamentCard.online(t, onTap: () => _open(t.id)),
                      ]),
                  ],
                ),
              );
  }
}

class _NextLocalMatch extends StatelessWidget {
  final Tournament tournament;
  final TnMatch match;
  final VoidCallback onTap;
  const _NextLocalMatch({
    required this.tournament,
    required this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Tv.panel2,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            key: const ValueKey('tn-next-match'),
            onTap: onTap,
            leading: Icon(Icons.sports_martial_arts, color: Tv.gold),
            title:
                Text('TON PROCHAIN MATCH', style: Tv.title(15, color: Tv.gold)),
            subtitle: Text(
              '${tournament.name} · ${tournament.roundName(match.round)} · '
              '${tournament.player(match.a)!.name} contre ${tournament.player(match.b)!.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tv.title(16, color: Tv.text),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
}

class _TournamentCard extends StatelessWidget {
  final TnSummary? online;
  final LocalTournament? local;
  final VoidCallback onTap;
  const _TournamentCard.online(TnSummary t, {required this.onTap})
      : online = t,
        local = null;
  const _TournamentCard.local(LocalTournament t, {required this.onTap})
      : local = t,
        online = null;

  @override
  Widget build(BuildContext context) {
    final t = online;
    final lt = local;
    final (status, color) =
        switch (t?.status ?? (lt!.winner == null ? 'running' : 'done')) {
      'open' => ('INSCRIPTIONS ${t!.count}/${t.size}', Tv.green),
      'running' => ('EN COURS', Tv.gold),
      _ => ('TERMINÉ', Tv.muted),
    };
    final bracket = lt?.view();
    final matches = bracket?.round(1).take(2).toList() ?? [];
    return InkWell(
      key: ValueKey(t != null ? 'tn-card-${t.id}' : 'tn-local-${lt!.uid}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Tv.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t?.joined == true ? Tv.gold : Tv.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (t?.name ?? lt!.name).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(21),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      (t?.label ?? lt!.label).toUpperCase(),
                      if (t != null)
                        '${t.size} PLACES'
                      else
                        '${lt!.players.length} JOUEURS',
                      if (t != null && t.owner != null)
                        'PAR ${t.owner!.name.toUpperCase()}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.label(11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              status,
                              style: Tv.title(13, color: color),
                            ),
                          ),
                        ),
                      ),
                      if (t?.joined == true) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'INSCRIT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tv.title(13, color: Tv.gold),
                          ),
                        ),
                      ],
                      if (t?.winner != null || lt?.winner != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '🏆 ${(t?.winner?.name ?? lt!.playerNo(lt.winner!).name).toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tv.title(14, color: Tv.goldLight),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TABLEAU', style: Tv.label(10)),
                  const SizedBox(height: 4),
                  if (bracket == null)
                    Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 22,
                          color: Tv.gold,
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text('VOIR', style: Tv.label(10))),
                      ],
                    )
                  else
                    for (final m in matches)
                      Text(
                        '${bracket.player(m.a)?.name ?? 'À venir'}'
                        ' / ${m.bye ? 'Exempt' : bracket.player(m.b)?.name ?? 'À venir'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tv.label(10),
                      ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Un tournoi : inscriptions, puis tableau ; mon match à jouer en haut.
class TournamentPage extends StatefulWidget {
  final int id;
  const TournamentPage({super.key, required this.id});

  /// Relecture du tournoi (faux en test : pas de minuterie).
  static bool poll = true;

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  Tournament? _t;
  String? _error;
  bool _busy = false;
  Timer? _timer;

  PlayerProfile? get _me => OnlineService.instance.me;
  int? get _myId => _me?.id;

  @override
  void initState() {
    super.initState();
    _load();
    if (TournamentPage.poll) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await TournamentApi.get(widget.id);
      PlayerStore.instance.ensureRatings(t.players.map((p) => p.key));
      MediaStore.instance.ensure(t.players.map((p) => p.key));
      // Pendant un match (partie ouverte par-dessus), la TV garde la partie :
      // le tableau revient dès que cette page est de nouveau au premier plan.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        TvLink.instance.pushTournament(t.toJson());
      }
      if (mounted) {
        setState(() {
          _t = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  Future<void> _run(Future<void> Function(String token) f) async {
    final me = _me;
    if (me == null || _busy) return;
    setState(() => _busy = true);
    try {
      await f(me.token);
      await _load();
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer le tournoi ?', style: Tv.title(22)),
        content: const Text('Le tableau et les résultats seront effacés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ANNULER')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('SUPPRIMER')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final me = _me;
    if (me == null) return;
    try {
      await TournamentApi.delete(me.token, widget.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    }
  }

  /// Lance mon match : défi à l'adversaire, attente, partie.
  Future<void> _play(TnMatch m) async {
    final t = _t, me = _me;
    if (t == null || me == null) return;
    final opp = t.player(m.a == me.id ? m.b : m.a);
    if (opp == null) return;
    int id;
    try {
      id = await OnlineService.instance
          .challengeTournament(t.id, m.round, m.slot, opp.online);
    } catch (e) {
      if (mounted) _toast(context, _err(e));
      return;
    }
    if (!mounted) return;
    final game = {
      ...t.game,
      'players': [
        {'id': me.key, 'name': me.name, 'team': 0},
        {'id': opp.key, 'name': opp.name, 'team': 1},
      ],
      'actions': const [],
      'tn': {
        't': t.id,
        'r': m.round,
        's': m.slot,
        'name': t.name,
        'rounds': t.rounds
      },
    };
    await waitForAnswer(context, id, opp.online, game);
    _load();
  }

  /// Le créateur déclare un vainqueur (forfait).
  Future<void> _declare(TnMatch m) async {
    final t = _t;
    if (t == null) return;
    final a = t.player(m.a), b = t.player(m.b);
    if (a == null || b == null) return;
    final w = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Qui gagne ce match ?', style: Tv.title(22)),
        content: const Text(
            'Forfait, ou match joué hors de l\'appli. Le vainqueur passe au tour suivant.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ANNULER')),
          for (final p in [a, b])
            FilledButton(
                onPressed: () => Navigator.pop(ctx, p.id),
                child: Text(p.name.toUpperCase())),
        ],
      ),
    );
    if (w == null) return;
    await _run((token) => TournamentApi.setWinner(token, t.id, m, w));
  }

  @override
  Widget build(BuildContext context) => GameThemeScope(
      skin: GameSkins.tournament, child: Builder(builder: _menuBuild));

  Widget _menuBuild(BuildContext context) {
    final t = _t;
    final owner = t != null && t.owner == _myId;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        title: Text(t == null ? 'TOURNOI' : t.name.toUpperCase(),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (t != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${t.label.toUpperCase()} · ${t.size} PLACES',
                    style: Tv.label(12, color: Tv.text)),
              ),
            ),
          if (owner)
            IconButton(
              tooltip: 'Supprimer le tournoi',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: t == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, style: Tv.title(16, color: Tv.red)))
          : t.open
              ? _registration(t, owner)
              : _bracketView(t, owner),
    );
  }

  // ─── Inscriptions ───

  Widget _registration(Tournament t, bool owner) {
    final me = _myId;
    final joined = t.players.any((p) => p.id == me);
    final full = t.players.length >= t.size;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              TvSection('Inscrits ${t.players.length}/${t.size}',
                  padding: const EdgeInsets.only(bottom: 8)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in t.players)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => openPlayerStats(context,
                          id: p.key, name: p.name, color: p.color),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: Tv.panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: p.id == t.owner ? Tv.gold : Tv.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlayerAvatar(
                                id: p.key,
                                name: p.name,
                                color: p.color,
                                size: 34),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.name.toUpperCase(), style: Tv.title(17)),
                                RankChip(p.key, size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (var i = t.players.length; i < t.size; i++)
                    Container(
                      width: 120,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Tv.line),
                      ),
                      child: Text('PLACE LIBRE', style: Tv.label(11)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ÉLIMINATION DIRECTE · EN LIGNE',
                    style: Tv.title(15, color: Tv.gold)),
                const SizedBox(height: 6),
                Text(
                    owner
                        ? 'Les autres joueurs trouvent ton tournoi dans « Tournois ». '
                            'Lance-le quand tout le monde est inscrit.'
                        : 'Le créateur lance le tournoi quand tout le monde est inscrit. '
                            'Tes matchs se jouent ensuite en ligne, chez toi.',
                    style: Tv.label(12, color: Tv.text)),
                const Spacer(),
                if (owner)
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      key: const ValueKey('tn-start'),
                      onPressed: _busy || t.players.length < 2
                          ? null
                          : () => _run((tok) => TournamentApi.start(tok, t.id)),
                      icon: const Icon(Icons.play_arrow),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            t.players.length < 2
                                ? 'IL FAUT 2 INSCRITS'
                                : 'LANCER LE TOURNOI',
                            style: Tv.title(20, color: Colors.black)),
                      ),
                    ),
                  )
                else if (joined)
                  OutlinedButton.icon(
                    key: const ValueKey('tn-leave'),
                    onPressed: _busy
                        ? null
                        : () => _run((tok) => TournamentApi.leave(tok, t.id)),
                    icon: const Icon(Icons.logout),
                    label: const Text('ME DÉSINSCRIRE'),
                  )
                else
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      key: const ValueKey('tn-join'),
                      onPressed: _busy || full
                          ? null
                          : () => _run((tok) => TournamentApi.join(tok, t.id)),
                      icon: const Icon(Icons.how_to_reg),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(full ? 'COMPLET' : 'M\'INSCRIRE',
                            style: Tv.title(20, color: Colors.black)),
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

  // ─── Tableau ───

  Widget _bracketView(Tournament t, bool owner) {
    final me = _myId;
    final mine = me == null ? null : t.myMatch(me);
    final champion = t.player(t.winner);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (champion != null)
          _Banner(
            color: Tv.gold,
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                PlayerAvatar(
                    id: champion.key,
                    name: champion.name,
                    color: champion.color,
                    size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      '${champion.name.toUpperCase()} REMPORTE LE TOURNOI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(20, color: Tv.goldLight)),
                ),
              ],
            ),
          )
        else if (mine != null)
          _Banner(
            color: Tv.green,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      'TON MATCH (${t.roundName(mine.round)}) CONTRE '
                      '${(t.player(mine.a == me ? mine.b : mine.a)?.name ?? '?').toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(18)),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const ValueKey('tn-play'),
                  onPressed: _busy ? null : () => _play(mine),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('JOUER'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _Bracket(
            t: t,
            me: me,
            onMatch: owner ? _declare : null,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Banner({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: child,
      );
}

/// Tableau : une colonne par tour, traits entre les matchs. Défile dans les
/// 2 sens si besoin (16 joueurs).
class _Bracket extends StatelessWidget {
  final Tournament t;
  final int? me;
  final void Function(TnMatch)? onMatch;

  /// Tout faire tenir à l'écran (TV : pas de défilement possible).
  final bool fit;
  const _Bracket(
      {required this.t, required this.me, this.onMatch, this.fit = false});

  static const cardW = 176.0, cardH = 62.0, gapX = 34.0, headH = 26.0;

  @override
  Widget build(BuildContext context) {
    final first = t.round(1).length;
    return LayoutBuilder(builder: (context, c) {
      // Hauteur d'une case du 1er tour : remplit l'écran si possible
      final unit = ((c.maxHeight - headH - 16) / first).clamp(cardH + 8, 140.0);
      final h = headH + unit * first + 8;
      final w = t.rounds * (cardW + gapX) + 12;
      final box = SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LinesPainter(t, unit),
              ),
            ),
            for (var r = 1; r <= t.rounds; r++) ...[
              Positioned(
                left: (r - 1) * (cardW + gapX),
                top: 0,
                width: cardW,
                height: headH,
                child: Center(
                  child:
                      Text(t.roundName(r), style: Tv.title(14, color: Tv.gold)),
                ),
              ),
              for (final m in t.round(r))
                Positioned(
                  left: (r - 1) * (cardW + gapX),
                  top: headH +
                      (m.slot + 0.5) * unit * (1 << (r - 1)) -
                      cardH / 2,
                  width: cardW,
                  height: cardH,
                  child: _MatchCard(
                    t: t,
                    m: m,
                    me: me,
                    onTap: onMatch != null && m.playable
                        ? () => onMatch!(m)
                        : null,
                  ),
                ),
            ],
          ],
        ),
      );
      if (fit) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(fit: BoxFit.contain, child: box),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SingleChildScrollView(child: box),
      );
    });
  }
}

class _LinesPainter extends CustomPainter {
  final Tournament t;
  final double unit;
  _LinesPainter(this.t, this.unit);

  @override
  void paint(Canvas canvas, Size size) {
    const cw = _Bracket.cardW, gx = _Bracket.gapX, hh = _Bracket.headH;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final lit = Paint()
      ..color = Tv.gold
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var r = 1; r < t.rounds; r++) {
      for (final m in t.round(r)) {
        final y = hh + (m.slot + 0.5) * unit * (1 << (r - 1));
        final ny = hh + (m.slot ~/ 2 + 0.5) * unit * (1 << r);
        final x0 = (r - 1) * (cw + gx) + cw;
        final x1 = x0 + gx;
        final path = Path()
          ..moveTo(x0, y)
          ..lineTo(x0 + gx / 2, y)
          ..lineTo(x0 + gx / 2, ny)
          ..lineTo(x1, ny);
        canvas.drawPath(path, m.winner != null ? lit : p);
      }
    }
  }

  @override
  bool shouldRepaint(_LinesPainter o) => true;
}

class _MatchCard extends StatelessWidget {
  final Tournament t;
  final TnMatch m;
  final int? me;
  final VoidCallback? onTap;
  const _MatchCard(
      {required this.t, required this.m, required this.me, this.onTap});

  @override
  Widget build(BuildContext context) {
    final mine = m.playable && (m.a == me || m.b == me);
    Widget line(int? id, {bool byeLine = false}) {
      final p = t.player(id);
      final won = id != null && m.winner == id;
      final lost = m.winner != null && id != null && !won;
      return Expanded(
        child: Opacity(
          opacity: lost ? 0.45 : 1,
          child: Row(
            children: [
              if (p != null)
                PlayerAvatar(id: p.key, name: p.name, color: p.color, size: 20)
              else
                const SizedBox(width: 20),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                      p?.name.toUpperCase() ?? (byeLine ? 'EXEMPT' : 'À VENIR'),
                      style: Tv.title(15,
                          color: won
                              ? Tv.goldLight
                              : p == null
                                  ? Tv.muted
                                  : Tv.text)),
                ),
              ),
              if (won)
                Icon(m.forfeit ? Icons.flag : Icons.check_circle,
                    size: 16, color: Tv.gold),
            ],
          ),
        ),
      );
    }

    return InkWell(
      key: ValueKey('tn-match-${m.round}-${m.slot}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF14261A) : Tv.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: mine
                  ? Tv.green
                  : m.winner != null
                      ? Tv.gold.withValues(alpha: 0.6)
                      : Tv.line,
              width: mine ? 2 : 1),
        ),
        child: Column(
          children: [
            line(m.a),
            Divider(height: 1, color: Tv.line),
            line(m.b, byeLine: m.bye),
          ],
        ),
      ),
    );
  }
}

/// Tournoi à la maison : tableau, prochain match à jouer sur cette cible,
/// vainqueur déclaré à la main si besoin. Le tableau s'affiche sur la TV
/// entre les matchs.
class LocalTournamentPage extends StatefulWidget {
  final String uid;

  /// Partie coupée à reprendre tout de suite : (partie, tour, emplacement).
  final (DartsGame, int, int)? resume;
  const LocalTournamentPage({super.key, required this.uid, this.resume});

  @override
  State<LocalTournamentPage> createState() => _LocalTournamentPageState();
}

class _LocalTournamentPageState extends State<LocalTournamentPage> {
  final store = LocalTournamentStore.instance;

  LocalTournament? get _lt => store.byUid(widget.uid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushTv();
      final r = widget.resume;
      final lt = _lt;
      if (r == null || lt == null) return;
      final (game, round, slot) = r;
      final m =
          lt.view().matches.where((m) => m.round == round && m.slot == slot);
      if (m.isNotEmpty && m.first.winner == null) _play(m.first, game: game);
    });
  }

  void _pushTv() {
    final lt = _lt;
    if (lt != null) TvLink.instance.pushTournament(lt.view().toJson());
  }

  Future<void> _play(TnMatch m, {DartsGame? game}) async {
    final lt = _lt;
    if (lt == null) return;
    game ??= gameFromJson(lt.gameFor(m));
    var tie = false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          game: game,
          tournament: {'uid': widget.uid, 'r': m.round, 's': m.slot},
          nextMatch: lt.view().nextLine(m.round, m.slot),
          onTournamentEnd: (g) {
            if (g.winners.length != 1) {
              tie = true;
              return;
            }
            final key = g.players[g.winners.first].id;
            final no = lt.players.indexWhere((p) => p.id == key) + 1;
            if (no > 0) {
              lt.advance(m.round, m.slot, no);
              store.save();
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    _pushTv();
    if (tie) _toast(context, 'Égalité : rejouez ce match');
  }

  Future<void> _matchSheet(TnMatch m) async {
    final lt = _lt;
    if (lt == null) return;
    final t = lt.view();
    final a = t.player(m.a)!, b = t.player(m.b)!;
    await showAppSheet(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                '${t.roundName(m.round)} · ${a.name.toUpperCase()} CONTRE ${b.name.toUpperCase()}',
                style: Tv.title(20)),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('tn-local-play'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _play(m);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text('JOUER CE MATCH',
                    style: Tv.title(20, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 14),
            Text('OU DÉCLARER LE VAINQUEUR (FORFAIT)', style: Tv.label(12)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final p in [a, b]) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        lt.advance(m.round, m.slot, p.id, forfeit: true);
                        store.save();
                        Navigator.pop(ctx);
                        setState(() {});
                        _pushTv();
                      },
                      child: Text(p.name.toUpperCase(),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (p == a) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer le tournoi ?', style: Tv.title(22)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ANNULER')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('SUPPRIMER')),
        ],
      ),
    );
    if (ok != true) return;
    await store.remove(widget.uid);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => GameThemeScope(
      skin: GameSkins.tournament, child: Builder(builder: _menuBuild));

  Widget _menuBuild(BuildContext context) {
    final lt = _lt;
    if (lt == null) {
      return const Scaffold(body: Center(child: Text('Tournoi introuvable')));
    }
    final t = lt.view();
    final next = t.nextMatch;
    final champion = t.player(t.winner);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        title: Text(t.name.toUpperCase(), overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Text(
                '${t.label.toUpperCase()} · ${t.players.length} JOUEURS · À LA MAISON',
                style: Tv.label(12, color: Tv.text)),
          ),
          IconButton(
            tooltip: 'Supprimer le tournoi',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (champion != null)
            _ChampionBanner(champion: champion)
          else if (next != null)
            _Banner(
              color: Tv.green,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        'PROCHAIN MATCH (${t.roundName(next.round)}) : '
                        '${t.player(next.a)!.name.toUpperCase()} CONTRE '
                        '${t.player(next.b)!.name.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tv.title(18)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    key: const ValueKey('tn-play'),
                    onPressed: () => _play(next),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('JOUER'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _Bracket(t: t, me: null, onMatch: _matchSheet),
          ),
        ],
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  final TnPlayer champion;
  final double size;
  const _ChampionBanner({required this.champion, this.size = 20});

  @override
  Widget build(BuildContext context) => _Banner(
        color: Tv.gold,
        child: Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: size * 1.3)),
            const SizedBox(width: 10),
            PlayerAvatar(
                id: champion.key,
                name: champion.name,
                color: champion.color,
                size: size * 1.7),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${champion.name.toUpperCase()} REMPORTE LE TOURNOI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tv.title(size, color: Tv.goldLight)),
            ),
          ],
        ),
      );
}

/// Écran TV : tableau du tournoi en grand, prochain match ou vainqueur.
class TvTournamentView extends StatefulWidget {
  final Tournament tournament;
  const TvTournamentView({super.key, required this.tournament});

  @override
  State<TvTournamentView> createState() => _TvTournamentViewState();
}

class _TvTournamentViewState extends State<TvTournamentView> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(TvTournamentView old) {
    super.didUpdateWidget(old);
    _ensure();
  }

  void _ensure() {
    final keys = widget.tournament.players.map((p) => p.key);
    MediaStore.instance.ensure(keys);
    PlayerStore.instance.ensureRatings(keys);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final next = t.nextMatch;
    final champion = t.player(t.winner);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: Tv.gold, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(36, color: Tv.gold)),
              ),
              Text(t.label.toUpperCase(), style: Tv.title(20, color: Tv.text)),
            ],
          ),
          if (champion != null)
            _ChampionBanner(champion: champion, size: 28)
          else if (next != null)
            _Banner(
              color: Tv.green,
              child: Text(
                  'PROCHAIN MATCH (${t.roundName(next.round)}) : '
                  '${t.player(next.a)?.name.toUpperCase() ?? '?'} CONTRE '
                  '${t.player(next.b)?.name.toUpperCase() ?? '?'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tv.title(24)),
            ),
          const SizedBox(height: 6),
          Expanded(child: _Bracket(t: t, me: null, fit: true)),
        ],
      ),
    );
  }
}
