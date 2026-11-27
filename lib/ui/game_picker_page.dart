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
            party ? _players(kPracticeInfo[k]!) : ''),
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
    ? '${i.minPlayers} joueurs'
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
                  child: GridView.builder(
                    key: const ValueKey('pick-grid'),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 130,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: .82),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _PickTile(
                      item: items[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SetupPage(kind: kind, game: items[i].id)),
                      ),
                    ),
                  ),
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
  Widget build(BuildContext context) {
    final c = item.tint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('pick-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c, width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(Colors.black, c, .35)!, Colors.black],
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
                  child: Image.asset(item.image,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
              // Même hauteur pour toutes les tuiles (avec ou sans sous-titre)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: c,
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
                          style: Band.text(Tv.title(15, color: Colors.white))),
                    ),
                    if (item.sub.isNotEmpty)
                      Text(item.sub.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.label(9, color: Colors.white70)),
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
