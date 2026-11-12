import 'dart:async';

import 'package:flutter/material.dart';

import '../game/x01.dart';
import '../media.dart';
import '../online/online.dart';
import '../players.dart';
import '../server.dart';
import '../tournament.dart';
import 'online_page.dart' show waitForAnswer;
import 'setup_page.dart';
import 'stats_page.dart' show openPlayerStats;
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

  PlayerProfile? get _me => OnlineService.instance.me;

  @override
  void initState() {
    super.initState();
    _load();
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
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        title: const Text('TOURNOIS'),
        actions: [
          if (me != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.icon(
                key: const ValueKey('tn-new'),
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('CRÉER UN TOURNOI'),
              ),
            ),
        ],
      ),
      body: me == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'Crée ton profil (Joueurs) pour jouer les tournois en ligne.',
                    textAlign: TextAlign.center,
                    style: Tv.title(18, color: Tv.text)),
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
                                child: const Text('RÉESSAYER')),
                          ],
                        ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _list!.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Text(
                                'Aucun tournoi pour l\'instant :\ncrée le premier !',
                                textAlign: TextAlign.center,
                                style: Tv.title(18, color: Tv.text)),
                          ),
                        ])
                      : LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth > 700 ? 2 : 1;
                          const gap = 10.0;
                          final w = (c.maxWidth - 24 - gap * (cols - 1)) / cols;
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                            children: [
                              Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final t in _list!)
                                    SizedBox(
                                        width: w,
                                        child: _SummaryCard(
                                            t: t, onTap: () => _open(t.id))),
                                ],
                              ),
                            ],
                          );
                        }),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TnSummary t;
  final VoidCallback onTap;
  const _SummaryCard({required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (status, color) = switch (t.status) {
      'open' => ('INSCRIPTIONS ${t.count}/${t.size}', Tv.green),
      'running' => ('EN COURS', Tv.gold),
      _ => ('TERMINÉ', Tv.muted),
    };
    return InkWell(
      key: ValueKey('tn-card-${t.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Tv.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.joined ? Tv.gold : Tv.line),
        ),
        child: Row(
          children: [
            Icon(t.status == 'done' ? Icons.emoji_events : Icons.account_tree,
                color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(21)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        t.label.toUpperCase(),
                        '${t.size} PLACES',
                        if (t.owner != null)
                          'PAR ${t.owner!.name.toUpperCase()}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.label(11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color),
                          ),
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(status,
                                  style: Tv.title(13, color: color))),
                        ),
                      ),
                      if (t.joined) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('INSCRIT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Tv.title(13, color: Tv.gold)),
                        ),
                      ],
                      if (t.winner != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('🏆 ${t.winner!.name.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Tv.title(14, color: Tv.goldLight)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
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
          .challengeTournament(t.id, m.round, m.slot, opp);
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
    await waitForAnswer(context, id, opp, game);
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
  Widget build(BuildContext context) {
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
  const _Bracket({required this.t, required this.me, this.onMatch});

  static const cardW = 176.0, cardH = 62.0, gapX = 34.0, headH = 26.0;

  @override
  Widget build(BuildContext context) {
    final first = t.round(1).length;
    return LayoutBuilder(builder: (context, c) {
      // Hauteur d'une case du 1er tour : remplit l'écran si possible
      final unit = ((c.maxHeight - headH - 16) / first).clamp(cardH + 8, 140.0);
      final h = headH + unit * first + 8;
      final w = t.rounds * (cardW + gapX) + 12;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SingleChildScrollView(
          child: SizedBox(
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
                      child: Text(t.roundName(r),
                          style: Tv.title(14, color: Tv.gold)),
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
          ),
        ),
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
