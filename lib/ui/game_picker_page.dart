// Mosaïque des jeux d'une tuile de l'accueil (01, Cricket, Entraînement,
// Party) : une tuile illustrée par jeu, défilement vers le bas ; toucher un
// jeu ouvre ses réglages (règles, joueurs) dans SetupPage.

import 'package:flutter/material.dart';

import '../game/cricket.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import 'game_theme.dart';
import 'setup_page.dart';
import 'setup_widgets.dart';
import 'theme.dart';

/// Un jeu de la mosaïque : [id] = valeur passée à `SetupPage(game:)`.
class PickItem {
  final String id;
  final String label;
  final String image;
  final Color tint;
  final String sub;
  const PickItem(this.id, this.label, this.image, this.tint, [this.sub = '']);
}

/// Jeux d'une famille (x01, cricket, practice, party), dans l'ordre affiché.
List<PickItem> pickItems(String kind) {
  if (kind == 'cricket') {
    return [
      for (final (i, v) in CricketVariant.values.indexed)
        PickItem(v.name, v.label, cricketArt(v),
            artTint(cricketArt(v)) ?? Band.at(i, CricketVariant.values.length)),
    ];
  }
  if (kind == 'practice' || kind == 'party') {
    final party = kind == 'party';
    final ks = [
      for (final k in PracticeKind.values)
        if (kPracticeInfo[k]!.party == party) k
    ];
    return [
      for (final (i, k) in ks.indexed)
        PickItem(
            k.name,
            kPracticeInfo[k]!.name,
            practiceArt(k),
            artTint(practiceArt(k)) ?? Band.at(i, ks.length),
            _players(kPracticeInfo[k]!)),
    ];
  }
  return [
    for (final (i, s) in kStartScores.indexed)
      PickItem('$s', '$s', x01Art(s),
          artTint(x01Art(s)) ?? Band.at(i, kStartScores.length)),
    const PickItem('freeze', 'Freeze', kFreezeArt, Band.ice, 'En équipes'),
  ];
}

String _players(PracticeInfo i) => i.minPlayers == i.maxPlayers
    ? '${i.minPlayers} joueur${i.minPlayers > 1 ? 's' : ''}'
    : '${i.minPlayers}-${i.maxPlayers} joueurs';

class GamePickerPage extends StatelessWidget {
  /// x01, cricket, practice ou party.
  final String kind;
  const GamePickerPage({super.key, required this.kind});

  String get _title => switch (kind) {
        'cricket' => 'Cricket',
        'practice' => 'Entraînement',
        'party' => 'Party',
        _ => '01',
      };

  @override
  Widget build(BuildContext context) {
    final items = pickItems(kind);
    return GameThemeScope(
      skin: GameSkins.of(kind, null),
      child: Scaffold(
        body: SafeArea(
          left: false,
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SetupBand(title: _title, sub: '${items.length} jeux'),
              Expanded(
                child: SidePad(
                  // tuiles en lignes centrées (une rangée incomplète
                  // reste au milieu)
                  child: LayoutBuilder(builder: (context, c) {
                    const gap = 10.0, pad = 12.0;
                    final w = c.maxWidth - 2 * pad;
                    final h = c.maxHeight - 26;
                    final n = items.length;
                    // rangées équilibrées (8 jeux = 2 × 4, pas 7 + 1)
                    final cols0 = ((w + gap) / (130 + gap)).ceil().clamp(1, 99);
                    final rows = (n / cols0).ceil().clamp(1, 99);
                    final cols = (n / rows).ceil();
                    var tw = ((w - (cols - 1) * gap) / cols).clamp(0.0, 210.0);
                    // tout tient en hauteur : tuiles aussi grandes que
                    // possible, sinon on fait défiler
                    final fitH = (h - (rows - 1) * gap) / rows * .82;
                    if (fitH >= (w - (cols0 - 1) * gap) / cols0) {
                      tw = tw.clamp(0.0, fitH);
                    }
                    final rowW = cols * tw + (cols - 1) * gap;
                    return SingleChildScrollView(
                      key: const ValueKey('pick-grid'),
                      padding: const EdgeInsets.fromLTRB(pad, 10, pad, 16),
                      // centré en hauteur quand tout tient dans l'écran
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: h),
                        child: Center(
                          child: SizedBox(
                            width: rowW + .5,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final it in items)
                                  SizedBox(
                                    width: tw,
                                    height: tw / .82,
                                    child: _PickTile(
                                      item: it,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => SetupPage(
                                                kind: kind, game: it.id)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final PickItem item;
  final VoidCallback onTap;
  const _PickTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _build(box.maxWidth));

  Widget _build(double w) {
    final c = item.tint;
    // Bandeau et nom qui grandissent avec la tuile (01 : 5 grandes tuiles)
    final k = w.isFinite ? (w / 130).clamp(1.0, 1.6) : 1.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('pick-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: .85), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(Colors.black, c, .35)!.withValues(alpha: .3),
                Colors.black.withValues(alpha: .2),
              ],
            ),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: .25), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Opacity(
                    opacity: .72,
                    child: Image.asset(item.image,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                ),
              ),
              // Même hauteur pour toutes les tuiles (avec ou sans sous-titre)
              Container(
                height: 40 * k,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .55),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(11)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(item.label.toUpperCase(),
                          maxLines: 1,
                          style: Band.text(Tv.title(
                              15 * k * (item.label.length <= 4 ? 1.7 : 1),
                              color: Colors.white))),
                    ),
                    if (item.sub.isNotEmpty)
                      Text(item.sub.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.label(9 * k.clamp(1.0, 1.2),
                              color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
