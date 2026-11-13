import 'package:flutter/material.dart';

import '../audio.dart';

import '../game/practice.dart';
import '../media.dart';
import '../players.dart';
import '../tv_link.dart';
import 'account_page.dart';
import 'dartboard.dart';
import 'media_editor.dart';
import 'theme.dart';
import 'widgets.dart';
import '../format.dart';
import '../rank.dart';
import 'stats_page.dart';

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

/// Rang + note sur 20 (ex. « CC · 4,56 »), à la couleur du rang.
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
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rankOf(rating).color, width: big ? 2.5 : 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rankOf(rating).label,
              style: Tv.title(big ? 26 : 16, color: rankOf(rating).color)),
          Text(rating.fr(2), style: Tv.label(big ? 13 : 10, color: Tv.text)),
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

  /// Comment l'annonceur dit le pseudo (« Sède » pour « ced »…).
  Future<void> _editPronunciation() async {
    final audio = AudioService.instance;
    final c = TextEditingController(
        text: audio.pronunciations[p.name.trim().toLowerCase()] ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Prononciation de ${p.name}', style: Tv.title(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Écris le pseudo comme il se prononce, par exemple '
                '« Sède » pour « ced ». Vide = le pseudo tel quel.'),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('pron-field'),
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: p.name),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => audio.speakTts(
                c.text.trim().isEmpty ? audio.spokenName(p.name) : c.text),
            icon: const Icon(Icons.volume_up),
            label: const Text('ÉCOUTER'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ANNULER')),
          FilledButton(
              key: const ValueKey('pron-ok'),
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (r != null) await audio.setPronunciation(p.name, r);
  }

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
                          child:
                              Text('PAS ENCORE DE RANG', style: Tv.label(12))),
                    if (p.rank != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              '${p.rank}${p.rank == 1 ? 'ER' : 'E'} AU CLASSEMENT',
                              style: Tv.title(16, color: Tv.gold)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const ValueKey('open-stats'),
                      onPressed: () => openPlayerStats(context,
                          id: p.key, name: p.name, color: p.color),
                      icon: const Icon(Icons.insights),
                      label: const Text('STATS ET RANG'),
                    ),
                    const SizedBox(height: 6),
                    if (p.expired)
                      FilledButton.icon(
                        onPressed: () =>
                            showAccountPage(context, pseudo: p.name),
                        icon: const Icon(Icons.login),
                        label: const Text('RECONNECTER'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => showColorSheet(context, p),
                      icon: ColorDot(p.color),
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
                    ListenableBuilder(
                      listenable: PlayerBoards.instance,
                      builder: (context, _) => OutlinedButton.icon(
                        key: const ValueKey('player-board'),
                        onPressed: () => showPlayerBoardSheet(context, p),
                        icon: const Icon(Icons.adjust),
                        label: Text(
                            'CIBLE : ${PlayerBoards.instance.of(p.key)?.name.toUpperCase() ?? 'PAR DÉFAUT'}',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ListenableBuilder(
                      listenable: AudioService.instance,
                      builder: (context, _) => OutlinedButton.icon(
                        key: const ValueKey('pronunciation'),
                        onPressed: _editPronunciation,
                        icon: const Icon(Icons.record_voice_over),
                        label: Text(
                            'PRONONCIATION : ${AudioService.instance.spokenName(p.name).toUpperCase()}',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(height: 6),
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
                        stat('Moyenne', p.average.fr(1)),
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
                        stat('MPR', (s['mpr'] as num?)?.fr(2) ?? '–'),
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
                                    ? 'MPR ${(g['mpr'] as num?)?.fr(2) ?? '–'}'
                                    : 'MOY ${(g['avg'] as num?)?.fr(1) ?? '–'}'
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

/// Cible du joueur : affichée pendant son tour (et sur la TV en attente
/// pour le profil principal). « Par défaut » = style général des options.
Future<void> showPlayerBoardSheet(BuildContext context, PlayerProfile p) =>
    showAppSheet(
      context,
      builder: (ctx) => ListenableBuilder(
        listenable: PlayerBoards.instance,
        builder: (ctx, _) {
          final cur = PlayerBoards.instance.of(p.key);
          Widget card(BoardSkin? sk) {
            final on = cur == sk;
            return InkWell(
              key: ValueKey('pboard-${sk?.id ?? 'default'}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                await PlayerBoards.instance.set(p.key, sk);
                TvLink.instance.refresh();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: on ? Tv.gold : Tv.line, width: on ? 2.5 : 1),
                ),
                child: Column(
                  children: [
                    sk == null
                        ? ValueListenableBuilder<BoardSkin>(
                            valueListenable: BoardSkin.current,
                            builder: (_, g, __) => Opacity(
                                opacity: 0.55,
                                child: DartboardPreview(skin: g, size: 104)),
                          )
                        : DartboardPreview(skin: sk, size: 104),
                    const SizedBox(height: 6),
                    Text(sk == null ? 'PAR DÉFAUT' : sk.name.toUpperCase(),
                        style:
                            Tv.title(18, color: on ? Tv.goldLight : Tv.text)),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TvSection('Cible de ${p.name}',
                    padding: const EdgeInsets.only(bottom: 10)),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    card(null),
                    for (final sk in BoardSkin.all) card(sk),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Affichée pendant son tour, téléphone et TV. Celle du profil principal reste sur l\'écran TV en attente. « Par défaut » = style choisi dans les options.',
                    style: Tv.label(12)),
              ],
            ),
          );
        },
      ),
    );
