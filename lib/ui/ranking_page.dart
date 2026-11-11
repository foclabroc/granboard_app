import 'package:flutter/material.dart';

import '../game/practice.dart';
import '../media.dart';
import '../players.dart';
import '../server.dart';
import 'players_page.dart' show RatingBadge;
import 'theme.dart';
import 'widgets.dart';

const _kinds = [
  ('rating', 'NOTE'),
  ('wins', 'VICTOIRES'),
  ('avg', 'MOYENNE'),
  ('n180', '180'),
  ('checkout', 'MEILLEURE FIN'),
  ('high', 'MEILLEURE MANCHE'),
  ('mpr', 'CRICKET MPR'),
  ('cr_wins', 'VICTOIRES CRICKET'),
];

/// Classements de tous les joueurs du serveur.
class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _kinds.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CLASSEMENTS'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: Tv.title(16),
            labelColor: Tv.gold,
            unselectedLabelColor: Tv.muted,
            indicatorColor: Tv.gold,
            tabs: [
              for (final k in _kinds) Tab(text: k.$2),
              const Tab(text: 'ENTRAÎNEMENT · FÊTE'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final k in _kinds) _TopList(kind: k.$1),
            const _PracticeTop(),
          ],
        ),
      ),
    );
  }
}

/// Meilleurs scores d'un jeu d'entraînement (au choix).
class _PracticeTop extends StatefulWidget {
  const _PracticeTop();

  @override
  State<_PracticeTop> createState() => _PracticeTopState();
}

class _PracticeTopState extends State<_PracticeTop> {
  PracticeKind _kind = PracticeKind.countUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 200,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final k in PracticeKind.values)
                ListTile(
                  dense: true,
                  selected: k == _kind,
                  selectedTileColor: Tv.panel2,
                  title: Text(kPracticeInfo[k]!.name.toUpperCase(),
                      style:
                          Tv.title(15, color: k == _kind ? Tv.gold : Tv.text)),
                  onTap: () => setState(() => _kind = k),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
            child: _TopList(key: ValueKey(_kind), kind: 'pr:${_kind.name}')),
      ],
    );
  }
}

class _TopList extends StatefulWidget {
  final String kind;
  const _TopList({super.key, required this.kind});

  @override
  State<_TopList> createState() => _TopListState();
}

class _TopListState extends State<_TopList> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final l = await GbServer.top(widget.kind);
    MediaStore.instance.ensure(l.map((r) => '${r['id']}'));
    return l;
  }

  void _retry() => setState(() => _future = _load());

  String _value(num v) => widget.kind == 'mpr'
      ? v.toStringAsFixed(2)
      : widget.kind == 'rating' || widget.kind == 'avg'
          ? v.toStringAsFixed(1)
          : '${v.toInt()}';

  @override
  Widget build(BuildContext context) {
    final mine = {for (final p in PlayerStore.instance.players) p.id};
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final e = snap.error;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is ApiError ? e.message : 'Erreur',
                    style: Tv.title(18, color: Tv.red)),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: _retry, child: const Text('RÉESSAYER')),
              ],
            ),
          );
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return Center(
            child: Text(
                const ['rating', 'avg', 'mpr'].contains(widget.kind)
                    ? 'Personne n\'a encore 3 parties'
                    : 'Pas encore de résultat',
                style: Tv.label(15, color: Tv.text)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _retry(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              final me = mine.contains((r['id'] as num).toInt());
              final value = r['value'] as num;
              final medal = switch (i) {
                0 => Tv.gold,
                1 => const Color(0xFFC0C4CC),
                2 => const Color(0xFFCD7F32),
                _ => Tv.muted,
              };
              return Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: me ? const Color(0xFF2A2210) : Tv.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: me ? Tv.gold : Tv.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Center(
                          child: Text('${i + 1}',
                              style: Tv.title(24, color: medal))),
                    ),
                    PlayerAvatar(
                        id: '${r['id']}',
                        name: '${r['pseudo']}',
                        color: kPlayerColors[
                            ((r['color'] as num?)?.toInt() ?? 0) %
                                kPlayerColors.length],
                        size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${r['pseudo']}'.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Tv.title(20, color: me ? Tv.goldLight : Tv.text)),
                    ),
                    Text('${r['games']} PARTIES   ', style: Tv.label(11)),
                    if (widget.kind == 'rating')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: RatingBadge(rating: value.toDouble()),
                      )
                    else
                      Container(
                        width: 80,
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Text(_value(value), style: Tv.title(24)),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
