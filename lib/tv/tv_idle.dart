// Écran TV en attente d'une partie : cible qui flotte, classements du
// serveur à gauche, dernières parties de la maison à droite.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../format.dart';
import '../server.dart';
import '../ui/dartboard.dart';
import '../ui/players_page.dart' show RatingBadge;
import '../ui/stats_page.dart' show colorOfIndex;
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Cible qui monte et descend doucement (sans tourner), ombre au sol.
class FloatingBoard extends StatefulWidget {
  final double size;
  const FloatingBoard({super.key, required this.size});

  @override
  State<FloatingBoard> createState() => _FloatingBoardState();
}

class _FloatingBoardState extends State<FloatingBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final lift = s * 0.05;
    return SizedBox(
      width: s,
      height: s + lift * 2 + s * 0.08,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value); // 0 bas, 1 haut
          final tilt = sin(_c.value * pi) * 0.025;
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // ombre qui rétrécit quand la cible monte
              Positioned(
                bottom: 0,
                child: Container(
                  width: s * (0.62 - 0.12 * t),
                  height: s * 0.06,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(s),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55 - 0.2 * t),
                          blurRadius: s * 0.06,
                          spreadRadius: s * 0.01)
                    ],
                  ),
                ),
              ),
              Positioned(
                top: lift * 2 * (1 - t),
                child: Transform.rotate(angle: tilt, child: child),
              ),
            ],
          );
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Tv.gold.withValues(alpha: 0.25),
                  blurRadius: s * 0.15,
                  spreadRadius: 4)
            ],
          ),
          // cible du profil principal du téléphone
          child: ListenableBuilder(
            listenable: PlayerBoards.instance,
            builder: (context, _) =>
                Dartboard(size: s, skin: PlayerBoards.instance.idle),
          ),
        ),
      ),
    );
  }
}

/// Cadre commun des 2 panneaux.
class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tv.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Tv.gold.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(gradient: Tv.goldGradient),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.black),
                const SizedBox(width: 6),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(title,
                        key: ValueKey(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tv.title(18, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Widget _empty(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            textAlign: TextAlign.center, style: Tv.label(13, color: Tv.muted)),
      ),
    );

// ─── Classements du serveur (défilent) ───

class TvTopPanel extends StatefulWidget {
  const TvTopPanel({super.key});

  /// (classement, titre)
  static const boards = [
    ('rating', 'TOP RANG'),
    ('avg', 'TOP MOYENNE 01'),
    ('mpr', 'TOP MPR CRICKET'),
    ('n180', 'TOP 180'),
    ('checkout', 'MEILLEURES FINS'),
  ];

  @override
  State<TvTopPanel> createState() => _TvTopPanelState();
}

class _TvTopPanelState extends State<TvTopPanel> {
  final _rows = <String, List<Map<String, dynamic>>>{};
  int _i = 0;
  Timer? _cycle, _reload;

  @override
  void initState() {
    super.initState();
    _load();
    _cycle = Timer.periodic(const Duration(seconds: 9), (_) => _next());
    _reload = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _reload?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    for (final (kind, _) in TvTopPanel.boards) {
      try {
        final r = await GbServer.top(kind, limit: 6);
        if (!mounted) return;
        setState(() => _rows[kind] = r);
      } catch (_) {}
    }
  }

  /// Classement suivant (on saute ceux qui sont vides).
  void _next() {
    if (!mounted) return;
    final n = TvTopPanel.boards.length;
    for (var k = 1; k <= n; k++) {
      final j = (_i + k) % n;
      if ((_rows[TvTopPanel.boards[j].$1] ?? const []).isNotEmpty) {
        setState(() => _i = j);
        return;
      }
    }
  }

  String _value(String kind, num v) => switch (kind) {
        'rating' || 'mpr' => v.fr(2),
        'avg' => v.fr(1),
        _ => '${v.toInt()}',
      };

  @override
  Widget build(BuildContext context) {
    final (kind, title) = TvTopPanel.boards[_i];
    final rows = _rows[kind] ?? const [];
    return _Panel(
      title: title,
      icon: Icons.emoji_events,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: KeyedSubtree(
          key: ValueKey(kind),
          child: rows.isEmpty
              ? _empty(_rows.isEmpty ? 'Chargement…' : 'Pas encore de résultat')
              : LayoutBuilder(builder: (context, c) {
                  final h = (c.maxHeight - 8) / 6;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length && i < 6; i++)
                          SizedBox(
                              height: h, child: _topRow(i, rows[i], kind, h)),
                      ],
                    ),
                  );
                }),
        ),
      ),
    );
  }

  Widget _topRow(int i, Map<String, dynamic> r, String kind, double h) {
    final medal = switch (i) {
      0 => Tv.gold,
      1 => const Color(0xFFC0C4CC),
      2 => const Color(0xFFCD7F32),
      _ => Tv.muted,
    };
    final color = colorOfIndex(r['color']);
    final fs = (h * 0.45).clamp(10.0, 26.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
              width: fs * 1.3,
              child: Text('${i + 1}', style: Tv.title(fs, color: medal))),
          PlayerAvatar(
              id: '${r['id']}',
              name: '${r['pseudo']}',
              color: color,
              size: (h * 0.7).clamp(16.0, 40.0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${r['pseudo']}'.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.title(fs, color: Tv.text)),
          ),
          if (kind == 'rating')
            FittedBox(
                child:
                    RatingBadge(rating: (r['value'] as num? ?? 0).toDouble()))
          else
            Text(_value(kind, r['value'] as num? ?? 0),
                style: Tv.title(fs, color: i == 0 ? Tv.goldLight : Tv.text)),
        ],
      ),
    );
  }
}

// ─── Dernières parties des joueurs du téléphone ───

/// Une partie retrouvée dans les profils (même date = même partie).
class _Played {
  final DateTime date;
  final String mode;
  final String kind;
  final players =
      <(String, int, bool, String)>[]; // pseudo, couleur, gagné, stat
  _Played(this.date, this.mode, this.kind);
}

class TvRecentPanel extends StatefulWidget {
  /// Comptes du téléphone relié (ids serveur).
  final List<int> ids;
  const TvRecentPanel({super.key, required this.ids});

  @override
  State<TvRecentPanel> createState() => _TvRecentPanelState();
}

class _TvRecentPanelState extends State<TvRecentPanel> {
  List<_Played>? _games;
  Timer? _reload;

  @override
  void initState() {
    super.initState();
    _load();
    _reload = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void didUpdateWidget(TvRecentPanel old) {
    super.didUpdateWidget(old);
    if (old.ids.join(',') != widget.ids.join(',')) _load();
  }

  @override
  void dispose() {
    _reload?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final byDate = <String, _Played>{};
    for (final id in widget.ids.take(12)) {
      Map<String, dynamic> p;
      try {
        p = await GbServer.profile(id);
      } catch (_) {
        continue;
      }
      for (final g in ((p['recent'] as List?) ?? const []).cast<Map>()) {
        final key = '${g['date']}|${g['mode']}';
        final date = DateTime.tryParse('${g['date']}')?.toLocal();
        if (date == null) continue;
        final game = byDate.putIfAbsent(
            key, () => _Played(date, '${g['mode']}', '${g['kind']}'));
        final stat = switch (game.kind) {
          'practice' => '${g['points'] ?? '–'}',
          'cricket' => '${(g['mpr'] as num?)?.fr(2) ?? '–'} MPR',
          _ => '${(g['avg'] as num?)?.fr(1) ?? '–'} MOY',
        };
        game.players.add((
          '${p['pseudo']}',
          (p['color'] as num?)?.toInt() ?? 0,
          g['won'] == true,
          stat
        ));
      }
    }
    if (!mounted) return;
    final list = byDate.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    setState(() => _games = list.take(4).toList());
  }

  static String _ago(DateTime d) {
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'À L\'INSTANT';
    if (m < 60) return 'IL Y A $m MIN';
    if (m < 24 * 60) return 'IL Y A ${m ~/ 60} H';
    final j = m ~/ (24 * 60);
    return j == 1 ? 'HIER' : 'IL Y A $j JOURS';
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    return _Panel(
      title: 'DERNIÈRES PARTIES',
      icon: Icons.history,
      child: games == null
          ? _empty('Chargement…')
          : games.isEmpty
              ? _empty(widget.ids.isEmpty
                  ? 'Aucun compte sur le téléphone'
                  : 'Pas encore de partie')
              : LayoutBuilder(builder: (context, c) {
                  final h = (c.maxHeight - 8) / 4;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final g in games)
                          SizedBox(height: h, child: _game(g, h)),
                      ],
                    ),
                  );
                }),
    );
  }

  Widget _game(_Played g, double h) {
    const fs = 20.0;
    final shown = g.players.take(3).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(g.mode.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tv.title(fs, color: Tv.goldLight)),
                  ),
                  Text(_ago(g.date),
                      style: Tv.label(fs * 0.7, color: Tv.muted)),
                ],
              ),
              for (final (name, color, won, stat) in shown)
                Row(
                  children: [
                    Icon(won ? Icons.emoji_events : Icons.circle,
                        size: won ? fs * 0.9 : fs * 0.45,
                        color: won ? Tv.gold : colorOfIndex(color)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.title(fs * 0.85,
                              color: won ? Tv.text : Tv.muted)),
                    ),
                    Text(stat, style: Tv.label(fs * 0.75, color: Tv.text)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
