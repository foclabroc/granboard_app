import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../game/practice.dart';
import '../players.dart';
import '../rank.dart';
import '../server.dart';
import 'theme.dart';
import 'widgets.dart';

/// Couleurs de la page (comme GranBoard) : PPR rose, MPR vert.
const _ppr = Color(0xFFFF3D7F);
const _mpr = Color(0xFF19D36B);

/// Ouvre la page de stats et de rang d'un joueur (n'importe lequel).
Future<void> openPlayerStats(BuildContext context,
        {required String id, required String name, required Color color}) =>
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlayerStatsPage(id: id, name: name, color: color)));

/// Stats et rang façon GranBoard : 01 / général / Cricket sur les 30
/// dernières parties (80 % ou 100 %), rang suivant, courbe PPR / MPR,
/// entraînement, tableau des rangs.
class PlayerStatsPage extends StatefulWidget {
  final String id;
  final String name;
  final Color color;
  const PlayerStatsPage(
      {super.key, required this.id, required this.name, required this.color});

  @override
  State<PlayerStatsPage> createState() => _PlayerStatsPageState();
}

class _PlayerStatsPageState extends State<PlayerStatsPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _all = false; // false = 80 %, true = 100 %

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await GbServer.stats(int.parse(widget.id));
      if (mounted) setState(() => _data = d);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    }
  }

  Grade get _grade => Grade.fromJson(
      (_data?[_all ? 'g100' : 'g80'] as Map?)?.cast<String, dynamic>());

  List<double> _series(String k) => [
        for (final p in (_data?[k] as List? ?? const []))
          ((p as Map)['v'] as num).toDouble()
      ];

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        title: Row(
          children: [
            PlayerAvatar(
                id: widget.id,
                name: widget.name,
                color: widget.color,
                size: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Text(widget.name.toUpperCase(),
                  overflow: TextOverflow.ellipsis, style: Tv.title(24)),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            key: const ValueKey('rank-table'),
            onPressed: () => showRankTable(context, _grade.rating),
            icon: const Icon(Icons.table_rows_outlined),
            label: const Text('TABLEAU DES RANGS'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: d == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: Tv.title(16, color: Tv.red)),
                        const SizedBox(height: 10),
                        OutlinedButton(
                            onPressed: _load, child: const Text('RÉESSAYER')),
                      ],
                    ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: [
                _rankRow(),
                const SizedBox(height: 10),
                _chart(),
                const SizedBox(height: 10),
                _practice(),
              ],
            ),
    );
  }

  // ─── Rangs ───

  Widget _rankRow() {
    final g = _grade;
    return SizedBox(
      height: 196,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: _Gauge(
                  title: '01',
                  rating: g.r01,
                  label: 'PPR',
                  value: g.ppr?.fr(2))),
          const SizedBox(width: 8),
          Expanded(
              child: _Gauge(
                  title: 'GÉNÉRAL',
                  rating: g.rating,
                  label: 'RATING',
                  value: g.rating?.fr(2))),
          const SizedBox(width: 8),
          Expanded(
              child: _Gauge(
                  title: 'CRICKET',
                  rating: g.rcr,
                  label: 'MPR',
                  value: g.mpr?.fr(2))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _overall(g)),
        ],
      ),
    );
  }

  Widget _overall(Grade g) {
    final r = g.rating;
    final next = r == null ? null : nextRank(r);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('MOYENNE DES 30 DERNIÈRES PARTIES',
                    maxLines: 2, style: Tv.label(11)),
              ),
              SegmentedButton<bool>(
                key: const ValueKey('stats-pct'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                segments: const [
                  ButtonSegment(value: false, label: Text('80 %')),
                  ButtonSegment(value: true, label: Text('100 %')),
                ],
                selected: {_all},
                onSelectionChanged: (v) => setState(() => _all = v.first),
              ),
            ],
          ),
          const Spacer(),
          if (r == null)
            Text('Pas encore de partie de 01 ou de Cricket',
                style: Tv.title(16, color: Tv.muted))
          else if (next == null)
            Text('RANG MAXIMUM', style: Tv.title(22, color: rankOf(r).color))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text('REQUIS POUR LE RANG SUIVANT',
                      style: Tv.label(12, color: Tv.text)),
                ),
                Text((next.from - r).clamp(0, 20).toDouble().fr(2),
                    style: Tv.title(30)),
                const SizedBox(width: 8),
                Text(next.label, style: Tv.title(22, color: next.color)),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _bar('PPR', g.ppr?.fr(2), _ppr)),
              Expanded(child: _bar('MPR', g.mpr?.fr(2), _mpr)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, String? value, Color color) => Container(
        height: 34,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Text(label, style: Tv.title(16, color: Colors.white)),
            const Spacer(),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value ?? '–',
                    style: Tv.title(24, color: Colors.white)),
              ),
            ),
          ],
        ),
      );

  // ─── Courbe ───

  Widget _chart() {
    final s01 = _series('s01');
    final scr = _series('scr');
    return _Card(
      child: SizedBox(
        height: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: TvSection('30 dernières parties',
                      padding: EdgeInsets.zero),
                ),
                _legend('PPR (01)', _ppr),
                const SizedBox(width: 14),
                _legend('MPR (CRICKET)', _mpr),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: s01.isEmpty && scr.isEmpty
                  ? Center(
                      child: Text('Aucune partie de 01 ou de Cricket',
                          style: Tv.label(13)))
                  : CustomPaint(
                      key: const ValueKey('stats-chart'),
                      size: Size.infinite,
                      painter: _ChartPainter(s01, scr),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String t, Color c) => Row(
        children: [
          Container(width: 14, height: 4, color: c),
          const SizedBox(width: 5),
          Text(t, style: Tv.label(11, color: c)),
        ],
      );

  // ─── Entraînement ───

  Widget _practice() {
    final p = (_data?['practice'] as Map?)?.cast<String, dynamic>() ?? {};
    final kinds = [
      for (final k in PracticeKind.values)
        if (p.containsKey(k.name)) k
    ];
    const colors = [
      Color(0xFF2F7BFF),
      Color(0xFF22D3B4),
      Color(0xFFB45CFF),
      Color(0xFFFF5C8A),
      Color(0xFF22C55E),
      Color(0xFFFF8A3D),
      Color(0xFFF2D43B),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TvSection('Analyse de l\'entraînement',
            padding: EdgeInsets.fromLTRB(2, 4, 0, 8)),
        if (kinds.isEmpty)
          Text('Aucun jeu d\'entraînement pour l\'instant', style: Tv.label(13))
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 8.0;
            final cols = c.maxWidth > 700 ? 3 : 2;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < kinds.length; i++)
                  SizedBox(
                    width: w,
                    child: _PracticeCard(
                      name: kPracticeInfo[kinds[i]]!.name,
                      data: Map<String, dynamic>.from(p[kinds[i].name] as Map),
                      color: colors[i % colors.length],
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Tv.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Tv.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

/// Carte avec l'anneau du rang (lettres au centre, avancement dans le rang).
class _Gauge extends StatelessWidget {
  final String title;
  final double? rating;
  final String label;
  final String? value;
  const _Gauge(
      {required this.title,
      required this.rating,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    final r = rating;
    final rank = r == null ? null : rankOf(r);
    final color = rank?.color ?? Tv.muted;
    return _Card(
      child: Column(
        children: [
          Text(title, style: Tv.title(16, color: Tv.text)),
          const SizedBox(height: 4),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _RingPainter(r == null ? 0 : rankProgress(r), color),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(rank?.label ?? '–',
                          style: Tv.title(44, color: color)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Tv.label(11, color: Tv.text)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value ?? '–', style: Tv.title(26)),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 0.07;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: s / 2 - stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect, 0, math.pi * 2, false, p..color = color.withValues(alpha: 0.25));
    if (progress > 0) {
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * progress, false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.color != color;
}

/// Courbe des 30 dernières parties : PPR (0-180, à droite de l'axe en rose)
/// et MPR (0-9, en vert) ; la partie la plus récente est à droite (« 1 »).
class _ChartPainter extends CustomPainter {
  final List<double> s01;
  final List<double> scr;
  _ChartPainter(this.s01, this.scr);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 58.0, bottom = 18.0, top = 6.0, right = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    void label(String t, Offset at, Color c,
        {TextAlign align = TextAlign.right}) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: Tv.label(10, color: c)),
          textDirection: TextDirection.ltr)
        ..layout();
      final dx = align == TextAlign.right
          ? at.dx - tp.width
          : align == TextAlign.center
              ? at.dx - tp.width / 2
              : at.dx;
      tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    }

    for (var i = 0; i <= 6; i++) {
      final y = top + h - h * i / 6;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      label((1.5 * i).fr(1), Offset(left - 28, y), _mpr);
      label('${30 * i}', Offset(left - 4, y), _ppr);
    }
    // 30 positions, la plus récente à droite
    double x(int fromEnd) => left + w - w * (fromEnd - 1) / 29;
    for (final n in [30, 25, 20, 15, 10, 5, 1]) {
      canvas.drawLine(Offset(x(n), top), Offset(x(n), top + h), grid);
      label('$n', Offset(x(n), top + h + 10), Tv.muted,
          align: TextAlign.center);
    }

    void series(List<double> v, double max, Color c) {
      if (v.isEmpty) return;
      final pts = [
        for (var i = 0; i < v.length; i++)
          Offset(x(v.length - i), top + h - h * (v[i] / max).clamp(0.0, 1.0))
      ];
      final line = Paint()
        ..color = c
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(Path()..addPolygon(pts, false), line);
      final dot = Paint()..color = c;
      for (final p in pts) {
        canvas.drawCircle(p, 3, dot);
      }
    }

    series(s01, 180, _ppr);
    series(scr, 9, _mpr);
  }

  @override
  bool shouldRepaint(_ChartPainter o) => o.s01 != s01 || o.scr != scr;
}

class _PracticeCard extends StatelessWidget {
  final String name;
  final Map<String, dynamic> data;
  final Color color;
  const _PracticeCard(
      {required this.name, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final avg = (data['avg'] as num?)?.toDouble();
    final best = (data['best'] as num?)?.toInt();
    final games = (data['games'] as num?)?.toInt() ?? 0;
    return _Card(
      child: Row(
        children: [
          Icon(Icons.keyboard_double_arrow_down_rounded,
              color: color, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.title(17)),
                    ),
                    Text(plural(games, 'PARTIE'), style: Tv.label(10)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(children: [
                          Text('MOYENNE ', style: Tv.label(11)),
                          Text(avg?.fr(2) ?? '–',
                              style: Tv.title(20, color: color)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(children: [
                          Text('MEILLEUR ', style: Tv.label(11)),
                          Text('${best ?? '–'}',
                              style: Tv.title(20, color: color)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau des rangs (fenêtre du bas, avec la croix) ; la ligne de la note
/// [rating] est en surbrillance.
Future<void> showRankTable(BuildContext context, double? rating) =>
    showAppSheet(
      context,
      builder: (context) {
        String range(List<double> lo, int i, int digits) => i == 19
            ? '${lo[19].fr(digits)}-'
            : '${lo[i].fr(digits)}-${(lo[i + 1] - (digits == 2 ? 0.01 : 0.01)).fr(digits)}';
        final cur = rating?.floor();
        TextStyle cell([Color c = Tv.text]) => Tv.title(15, color: c);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TvSection('Tableau des rangs',
                  padding: EdgeInsets.only(bottom: 4)),
              Text(
                  'Calculé sur les 30 dernières parties. « 80 % » ne garde que les '
                  '80 % meilleures (comme GranBoard), « 100 % » les compte toutes.',
                  style: Tv.label(11)),
              const SizedBox(height: 8),
              Table(
                key: const ValueKey('rank-table-grid'),
                border: TableBorder.all(color: Tv.line),
                columnWidths: const {
                  0: FlexColumnWidth(0.8),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.6),
                  3: FlexColumnWidth(1.3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Tv.panel2),
                    children: [
                      for (final h in ['RANG', 'NOTE', '01 PPR', 'CR MPR'])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(h,
                              textAlign: TextAlign.center,
                              style: Tv.label(12, color: Tv.text)),
                        ),
                    ],
                  ),
                  for (var n = 20; n >= 1; n--)
                    TableRow(
                      decoration: BoxDecoration(
                          color: n == cur
                              ? rankOf(n.toDouble())
                                  .color
                                  .withValues(alpha: 0.22)
                              : null),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                              n == 20 ||
                                      rankOf(n.toDouble()).label !=
                                          rankOf(n + 1.0).label
                                  ? rankOf(n.toDouble()).label
                                  : '',
                              textAlign: TextAlign.center,
                              style: Tv.title(17,
                                  color: rankOf(n.toDouble()).color)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(n.toDouble().fr(2),
                              textAlign: TextAlign.center, style: cell()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(range(kPprBounds, n - 1, 2),
                              textAlign: TextAlign.center, style: cell()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(range(kMprBounds, n - 1, 2),
                              textAlign: TextAlign.center, style: cell()),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );

/// Couleur d'un joueur à partir de son index de couleur serveur.
Color colorOfIndex(Object? c) =>
    kPlayerColors[((c as num?)?.toInt() ?? 0) % kPlayerColors.length];
