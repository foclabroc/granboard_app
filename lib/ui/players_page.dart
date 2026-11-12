import 'package:flutter/material.dart';

import '../game/practice.dart';
import '../media.dart';
import '../players.dart';
import 'account_page.dart';
import 'media_editor.dart';
import 'theme.dart';
import 'widgets.dart';

/// Joueurs mémorisés sur ce téléphone.
class PlayersPage extends StatelessWidget {
  const PlayersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PlayerStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('JOUEURS')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountPage(context),
        icon: const Icon(Icons.person_add),
        label: const Text('AJOUTER UN JOUEUR'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.players.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucun joueur sur ce téléphone.\nAjoute un joueur : crée un '
                  'compte ou connecte-toi avec ton pseudo et ton code.',
                  textAlign: TextAlign.center,
                  style: Tv.label(15, color: Tv.text),
                ),
              ),
            );
          }
          return GridView.extent(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            maxCrossAxisExtent: 280,
            childAspectRatio: 2.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final p in store.players) _PlayerCard(player: p),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerProfile player;
  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final p = player;
    final r = p.rating;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: Tv.panelGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.expired ? Tv.red : Tv.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PlayerDetailPage(player: p))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                PlayerAvatar.of(p, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.title(20)),
                      Text(
                        p.expired
                            ? 'À RECONNECTER'
                            : PlayerStore.instance.isOwner(p)
                                ? 'PROFIL PRINCIPAL'
                                : '${p.games} PARTIE${p.games > 1 ? 'S' : ''} · '
                                    '${p.wins} VICTOIRE${p.wins > 1 ? 'S' : ''}',
                        style: Tv.label(11,
                            color: p.expired
                                ? Tv.red
                                : PlayerStore.instance.isOwner(p)
                                    ? Tv.gold
                                    : Tv.muted),
                      ),
                    ],
                  ),
                ),
                if (r != null) RatingBadge(rating: r),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Note + classe (ex. « 52.3 · A »).
class RatingBadge extends StatelessWidget {
  final double rating;
  final bool big;
  const RatingBadge({super.key, required this.rating, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: big ? 14 : 8, vertical: big ? 6 : 3),
      decoration: BoxDecoration(
        gradient: Tv.goldGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ratingClass(rating),
              style: Tv.title(big ? 26 : 16, color: Colors.black)),
          Text(rating.toStringAsFixed(1),
              style: Tv.label(big ? 13 : 10, color: Colors.black87)),
        ],
      ),
    );
  }
}

class PlayerDetailPage extends StatefulWidget {
  final PlayerProfile player;
  const PlayerDetailPage({super.key, required this.player});

  @override
  State<PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends State<PlayerDetailPage> {
  final store = PlayerStore.instance;
  PlayerProfile get p => widget.player;

  @override
  void initState() {
    super.initState();
    store.refreshProfile(p);
  }

  Future<void> _forget() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${p.name} de ce téléphone ?', style: Tv.title(20)),
        content: const Text('Le compte et ses statistiques restent sur le '
            'serveur : il suffira de se reconnecter avec le pseudo et le code.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    await store.forget(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = p.stats;
        int n(String k) => (s[k] as num?)?.toInt() ?? 0;
        final recent = (p.profile?['recent'] as List?) ?? const [];

        Widget stat(String label, String value) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Tv.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Tv.line),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: Tv.title(24)),
                    Text(label.toUpperCase(), style: Tv.label(10)),
                  ],
                ),
              ),
            );

        return Scaffold(
          appBar: AppBar(title: Text(p.name.toUpperCase())),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Identité
              SizedBox(
                width: 230,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap:
                            p.expired ? null : () => showPhotoSheet(context, p),
                        child: Stack(
                          children: [
                            PlayerAvatar.of(p, size: 84),
                            if (!p.expired)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Tv.gold,
                                  child: const Icon(Icons.photo_camera,
                                      size: 16, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (p.rating != null)
                      Center(child: RatingBadge(rating: p.rating!, big: true))
                    else
                      Center(
                          child: Text('NOTE APRÈS 3 PARTIES',
                              style: Tv.label(12))),
                    if (p.rank != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              '${p.rank}${p.rank == 1 ? 'ER' : 'E'} AU CLASSEMENT',
                              style: Tv.title(16, color: Tv.gold)),
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (p.expired)
                      FilledButton.icon(
                        onPressed: () =>
                            showAccountPage(context, pseudo: p.name),
                        icon: const Icon(Icons.login),
                        label: const Text('RECONNECTER'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => store.setColor(
                          p, (p.colorIndex + 1) % kPlayerColors.length),
                      icon: Icon(Icons.palette, color: p.color),
                      label: const Text('COULEUR'),
                    ),
                    const SizedBox(height: 6),
                    if (!p.expired) ...[
                      ListenableBuilder(
                        listenable: MediaStore.instance,
                        builder: (context, _) {
                          final s = MediaStore.instance.soundOf(p.key);
                          return OutlinedButton.icon(
                            onPressed: () => showTurnSoundSheet(context, p),
                            icon: const Icon(Icons.music_note),
                            label: Text(
                                'SON : ${s.isEmpty ? 'AUCUN' : s == kVoiceSound ? 'MA VOIX' : kTurnSounds[s]?.toUpperCase() ?? s}',
                                overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (!store.isOwner(p)) ...[
                      OutlinedButton.icon(
                        onPressed: () => store.setOwner(p),
                        icon: const Icon(Icons.star_outline),
                        label: const Text('PROFIL PRINCIPAL'),
                      ),
                      const SizedBox(height: 6),
                    ],
                    OutlinedButton.icon(
                      onPressed: _forget,
                      icon: const Icon(Icons.logout),
                      label: const Text('RETIRER'),
                    ),
                  ],
                ),
              ),
              // Stats + parties
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  children: [
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.0,
                      children: [
                        stat('Parties', '${n('games')}'),
                        stat('Victoires', '${n('wins')}'),
                        stat('Moyenne', p.average.toStringAsFixed(1)),
                        stat('Fléchettes', '${n('darts')}'),
                        stat('Meilleure fin',
                            n('best_co') == 0 ? '–' : '${n('best_co')}'),
                        stat('Meilleure manche', '${n('high')}'),
                        stat('100+', '${n('n100')}'),
                        stat('180', '${n('n180')}'),
                      ],
                    ),
                    const TvSection('Cricket',
                        padding: EdgeInsets.fromLTRB(0, 14, 0, 6)),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.0,
                      children: [
                        stat('Parties', '${n('cr_games')}'),
                        stat('Victoires', '${n('cr_wins')}'),
                        stat('MPR',
                            (s['mpr'] as num?)?.toStringAsFixed(2) ?? '–'),
                        stat('Meilleure manche',
                            n('cr_best') == 0 ? '–' : '${n('cr_best')} M'),
                      ],
                    ),
                    if ((s['practice'] as Map?)?.isNotEmpty ?? false) ...[
                      const TvSection('Entraînement · meilleurs scores',
                          padding: EdgeInsets.fromLTRB(0, 14, 0, 6)),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in (s['practice'] as Map).entries)
                            Chip(
                              label: Text(
                                  '${kPracticeInfo[PracticeKind.values.where((k) => k.name == e.key).firstOrNull]?.name ?? e.key} : '
                                  '${(e.value as Map)['best']}',
                                  style: Tv.title(15)),
                            ),
                        ],
                      ),
                    ],
                    const TvSection('Dernières parties',
                        padding: EdgeInsets.fromLTRB(0, 16, 0, 6)),
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                            p.profile == null
                                ? 'Profil pas encore chargé (hors ligne ?)'
                                : 'Aucune partie pour l\'instant',
                            style: Tv.label(13, color: Tv.text)),
                      ),
                    for (final g in recent.cast<Map>())
                      ListTile(
                        dense: true,
                        leading: Icon(
                            g['won'] == true ? Icons.emoji_events : Icons.close,
                            color: g['won'] == true ? Tv.gold : Tv.muted),
                        title: Text('${g['mode']}', style: Tv.title(17)),
                        subtitle: Text(_date('${g['date']}')),
                        trailing: Text(
                            g['kind'] == 'practice'
                                ? 'SCORE ${g['points'] ?? '–'}'
                                : g['kind'] == 'cricket'
                                    ? 'MPR ${(g['mpr'] as num?)?.toStringAsFixed(2) ?? '–'}'
                                    : 'MOY ${(g['avg'] as num?)?.toStringAsFixed(1) ?? '–'}'
                                        '${g['checkout'] == null ? '' : '  ·  FIN ${g['checkout']}'}',
                            style: Tv.label(13, color: Tv.text)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _date(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
