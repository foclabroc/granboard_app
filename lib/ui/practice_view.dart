import 'package:flutter/material.dart';

import '../audio.dart';
import '../game/practice.dart';
import '../players.dart';
import 'dartboard.dart';
import 'game_fx.dart';
import 'game_page.dart' show GamePage;
import 'theme.dart';
import 'widgets.dart';

Color _colorOf(PracticeGame g, int i) =>
    PlayerStore.instance.distinctColors([for (final p in g.players) p.id])[i];

/// Partie d'entraînement : cible animée (zones à viser) | joueur en cours
/// (+ boutons) | scores. Partagé par le téléphone et l'écran TV.
class PracticeLayout extends StatelessWidget {
  final PracticeGame game;
  final GlobalKey<GameSplashState> splashKey;
  final Widget? actionBar;

  /// Choix de cible : ouvre le choix du numéro (téléphone seulement).
  final void Function(int number)? onChangeTarget;
  const PracticeLayout(
      {super.key,
      required this.game,
      required this.splashKey,
      this.actionBar,
      this.onChangeTarget});

  @override
  Widget build(BuildContext context) {
    final t = game.currentTurn;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) => Padding(
                padding: const EdgeInsets.all(6),
                child: game.grid != null
                    ? _GridView(
                        game: game, grid: game.grid!, size: c.maxHeight - 12)
                    : AnimatedDartboard(
                        size: c.maxHeight - 12,
                        hits: [
                          for (final d in t.darts.length > 3
                              ? t.darts.sublist(t.darts.length - 3)
                              : t.darts)
                            if (d.hit != null) d.hit!
                        ],
                        targets: game.finished ? const [] : game.targetZones,
                        win: game.finished,
                        dartColor: _colorOf(game, game.current),
                      ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Expanded(
                      child:
                          _Panel(game: game, onChangeTarget: onChangeTarget)),
                  if (actionBar != null) actionBar!,
                ],
              ),
            ),
            Expanded(flex: 4, child: _Scores(game: game)),
          ],
        ),
        Positioned.fill(
            child: IgnorePointer(child: GameSplash(key: splashKey))),
      ],
    );
  }
}

/// Grille (Two Line, Morpion, Cache-cache) à la place de la cible.
class _GridView extends StatelessWidget {
  final PracticeGame game;
  final PracticeGrid grid;
  final double size;
  const _GridView({required this.game, required this.grid, required this.size});

  @override
  Widget build(BuildContext context) {
    final rows = (grid.cells.length / grid.cols).ceil();
    final cell = size / grid.cols;
    final h = size * rows / grid.cols;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: size,
          height: h,
          child: GridView.count(
            crossAxisCount: grid.cols,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (final c in grid.cells)
                Builder(builder: (context) {
                  final color = c.owner == null
                      ? null
                      : _colorOf(
                          game, c.owner!.clamp(0, game.players.length - 1));
                  return Container(
                    margin: EdgeInsets.all(cell * 0.04),
                    decoration: BoxDecoration(
                      color: c.star
                          ? Tv.gold.withValues(alpha: 0.25)
                          : color?.withValues(alpha: 0.75) ??
                              (c.open ? Tv.panel2 : Tv.panel),
                      borderRadius: BorderRadius.circular(cell * 0.12),
                      border: Border.all(
                          color: color ?? (c.star ? Tv.gold : Tv.line),
                          width: 1.5),
                    ),
                    padding: EdgeInsets.all(cell * 0.05),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.star)
                            Icon(Icons.star_rounded,
                                color: Tv.gold, size: cell * 0.5)
                          else
                            Text(c.label,
                                style:
                                    Tv.title(cell * 0.42, color: Colors.white)),
                          if (c.sub != null && c.sub!.isNotEmpty)
                            Text(c.sub!,
                                style: Tv.title(cell * 0.2,
                                    color: Colors.white70)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final PracticeGame game;
  final void Function(int number)? onChangeTarget;
  const _Panel({required this.game, this.onChangeTarget});

  Future<void> _pick(BuildContext context) async {
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nouvelle cible', style: Tv.title(22)),
        content: SizedBox(
          width: 420,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in [for (var i = 1; i <= 20; i++) i, 25])
                ActionChip(
                  label: Text(n == 25 ? 'BULL' : '$n', style: Tv.title(18)),
                  onPressed: () => Navigator.pop(ctx, n),
                ),
            ],
          ),
        ),
      ),
    );
    if (n != null) onChangeTarget?.call(n);
  }

  @override
  Widget build(BuildContext context) {
    final g = game;
    final p = g.currentPlayer;
    final st = g.stateOf(g.current);
    final t = g.currentTurn;
    String status = '';
    Color statusColor = Tv.muted;
    if (g.finished) {
      final names = g.winners.map((i) => g.players[i].name).join(', ');
      status = '🏆 $names ${g.winners.length > 1 ? 'gagnent' : 'gagne'} !';
      statusColor = Tv.goldLight;
    } else if (t.note != null) {
      status = t.note!;
      statusColor = Tv.goldLight;
    } else if (g.turnOver) {
      status = 'Retire tes fléchettes · « Suivant »';
    } else {
      status = g.infoOf(g.current);
      statusColor = Tv.text;
    }
    final shown =
        t.darts.length > 3 ? t.darts.sublist(t.darts.length - 3) : t.darts;
    final extra = t.maxDarts > 3
        ? ' · FLÉCHETTE ${t.darts.length + 1}/${t.maxDarts}'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: Tv.gold, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(
                  id: p.id,
                  name: p.name,
                  color: _colorOf(g, g.current),
                  size: 30),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(p.name.toUpperCase(),
                      maxLines: 1, style: Tv.title(24)),
                ),
              ),
              const SizedBox(width: 8),
              RankChip(p.id, size: 14),
              if (st.out) ...[
                const SizedBox(width: 6),
                Text('ÉLIMINÉ', style: Tv.title(16, color: Tv.red)),
              ],
            ],
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    child: Text(g.scoreText(g.current),
                        style: Tv.title(96, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CIBLE$extra', style: Tv.label(11)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(g.finished ? '–' : g.targetLabel,
                            style: Tv.title(30, color: Tv.gold)),
                      ),
                      if (g.canChangeTarget && onChangeTarget != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact),
                          onPressed: () => _pick(context),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('CHANGER'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tv.title(16, color: statusColor)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                    child: _Slot(dart: i < shown.length ? shown[i] : null)),
              Container(
                width: 64,
                height: 48,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  gradient: Tv.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('MANCHE',
                          style: Tv.label(10, color: Colors.black87)),
                      Text('${t.points}',
                          style: Tv.title(22, color: Colors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final PracticeDart? dart;
  const _Slot({required this.dart});

  @override
  Widget build(BuildContext context) {
    final d = dart;
    final h = d?.hit;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: d == null
            ? Colors.black26
            : d.ok
                ? Tv.green
                : Tv.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d == null ? Tv.line : Colors.white24),
      ),
      alignment: Alignment.center,
      child: d == null
          ? Text('—', style: Tv.title(20, color: Tv.line))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(h == null ? 'RATÉ' : h.label,
                      style:
                          Tv.title(22, color: d.ok ? Colors.white : Tv.muted)),
                  if (d.points != 0)
                    Text('${d.points > 0 ? '+' : ''}${d.points}',
                        style: Tv.label(10, color: Colors.white)),
                ],
              ),
            ),
    );
  }
}

class _Scores extends StatelessWidget {
  final PracticeGame game;
  const _Scores({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    return LayoutBuilder(builder: (context, c) {
      final rowH = scoreRowHeight(c.maxHeight, g.players.length);
      return ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          for (var i = 0; i < g.players.length; i++)
            Builder(builder: (context) {
              final current = i == g.current && !g.finished;
              final st = g.stateOf(i);
              final won = g.winners.contains(i);
              final info = g.infoOf(i);
              return Opacity(
                opacity: st.out ? 0.5 : 1,
                child: ScoreRow(
                  id: g.players[i].id,
                  color: _colorOf(g, i),
                  current: current,
                  name: '${won ? '🏆 ' : ''}${g.players[i].name.toUpperCase()}',
                  info: st.out
                      ? 'ÉLIMINÉ'
                      : st.done
                          ? 'TERMINÉ'
                          : info,
                  score: g.scoreText(i),
                  height: rowH,
                  scoreWidth: 92,
                ),
              );
            }),
        ],
      );
    });
  }
}

// ─── Résultats ───

class PracticeResultsPage extends StatefulWidget {
  final PracticeGame game;
  final Future<bool>? saving;
  final bool tv;
  const PracticeResultsPage(
      {super.key, required this.game, this.saving, this.tv = false});

  @override
  State<PracticeResultsPage> createState() => _PracticeResultsPageState();
}

class _PracticeResultsPageState extends State<PracticeResultsPage> {
  PracticeGame get g => widget.game;

  @override
  void initState() {
    super.initState();
    AudioService.instance.startMusic();
    widget.saving?.then((ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Partie enregistrée sur le serveur'
              : 'Hors ligne : la partie sera envoyée plus tard')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final medals = {
      1: Tv.gold,
      2: const Color(0xFFC0C4CC),
      3: const Color(0xFFCD7F32)
    };
    final reason = switch (g.endReason) {
      PracticeEnd.goal =>
        'OBJECTIF ATTEINT EN ${g.round} MANCHE${g.round > 1 ? 'S' : ''}',
      PracticeEnd.limit => '${g.round} MANCHES JOUÉES',
      PracticeEnd.allOut => 'TOUT LE MONDE EST ÉLIMINÉ',
      null => 'PARTIE ARRÊTÉE',
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        automaticallyImplyLeading: false,
        title: Text('RÉSULTATS · ${g.title.toUpperCase()}'),
      ),
      body: TvBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          children: [
            Center(child: Text(reason, style: Tv.label(13))),
            const SizedBox(height: 8),
            for (final (rank, i) in g.ranking.indexed)
              Builder(builder: (context) {
                final st = g.stateOf(i);
                final won = g.winners.contains(i);
                final pct =
                    st.darts == 0 ? 0 : (st.good * 100 / st.darts).round();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                  decoration: BoxDecoration(
                    gradient: Tv.panelGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: won ? Tv.gold : Tv.line, width: won ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text('${rank + 1}',
                            style: Tv.title(30,
                                color: medals[rank + 1] ?? Tv.muted)),
                      ),
                      PlayerAvatar(
                          id: g.players[i].id,
                          name: g.players[i].name,
                          color: _colorOf(g, i),
                          size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${won ? '🏆 ' : ''}${g.players[i].name.toUpperCase()}',
                                style: Tv.title(20)),
                            Text(
                                '${st.darts} FLÉCHETTES · RÉUSSITE $pct %'
                                '${st.out ? ' · ÉLIMINÉ' : ''}',
                                style: Tv.label(11, color: Tv.text)),
                          ],
                        ),
                      ),
                      Text(g.scoreText(i),
                          style: Tv.title(30, color: Tv.goldLight)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      bottomNavigationBar: widget.tv
          ? null
          : Container(
              color: Tv.panel,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46)),
                          onPressed: () =>
                              Navigator.popUntil(context, (r) => r.isFirst),
                          icon: const Icon(Icons.home),
                          label: const Text('MENU PRINCIPAL'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46)),
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => GamePage(
                                    game: PracticeGame(
                                        g.settings.withSeed(DateTime.now()
                                            .microsecondsSinceEpoch),
                                        g.players))),
                          ),
                          icon: const Icon(Icons.replay),
                          label: Text('REJOUER',
                              style: Tv.title(20, color: Colors.black)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
