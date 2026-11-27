import 'package:flutter/material.dart';

import '../audio.dart';

import '../game/practice.dart';
import '../media.dart';
import '../players.dart';
import '../server.dart';
import '../tv_link.dart';
import 'account_page.dart';
import 'dartboard.dart';
import 'media_editor.dart';
import 'theme.dart';
import 'tile_fx.dart';
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
      appBar:
          AppBar(title: const Text('JOUEURS'), actions: const [HomeButton()]),
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

  /// Onglet affiché à droite : stats | perso | games.
  String _tab = 'stats';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
            title: Text(p.name.toUpperCase()), actions: const [HomeButton()]),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Identité + onglets : fixe, ne défile pas
            SizedBox(width: 200, child: _identity()),
            Expanded(
              child: switch (_tab) {
                'perso' => _perso(),
                'games' => _games(),
                _ => _stats(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity() => LayoutBuilder(builder: (context, box) {
        // photo plus petite si l'écran est bas : la colonne ne défile jamais
        final photo = (box.maxHeight - 210).clamp(44.0, 84.0);
        Widget tab(String id, IconData icon, String label) {
          final on = _tab == id;
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: on
                  ? FilledButton.icon(
                      key: ValueKey('tab-$id'),
                      onPressed: () {},
                      icon: Icon(icon, size: 18),
                      label: Text(label, overflow: TextOverflow.ellipsis),
                      style: FilledButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12)),
                    )
                  : OutlinedButton.icon(
                      key: ValueKey('tab-$id'),
                      onPressed: () => setState(() => _tab = id),
                      icon: Icon(icon, size: 18),
                      label: Text(label, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: Tv.muted),
                    ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Column(
            children: [
              GestureDetector(
                onTap: p.expired ? null : () => showPhotoSheet(context, p),
                child: Stack(
                  children: [
                    PlayerAvatar.of(p, size: photo),
                    if (!p.expired)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: Tv.gold,
                          child: const Icon(Icons.photo_camera,
                              size: 15, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (p.rating != null)
                    RatingBadge(rating: p.rating!)
                  else
                    Text('PAS ENCORE\nDE RANG',
                        textAlign: TextAlign.center, style: Tv.label(11)),
                  if (p.rank != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          '${p.rank}${p.rank == 1 ? 'ER' : 'E'} AU\nCLASSEMENT',
                          style: Tv.title(15, color: Tv.gold)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              tab('stats', Icons.insights, 'STATS'),
              tab('perso', Icons.tune, 'PERSONNALISER'),
              tab('games', Icons.format_list_bulleted, 'PARTIES'),
            ],
          ),
        );
      });

  Widget _stat(String label, String value) => Container(
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

  Widget _grid(List<Widget> children) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.0,
        children: children,
      );

  Widget _stats() {
    final s = p.stats;
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;
    return ListView(
      key: const ValueKey('pane-stats'),
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
      children: [
        _grid([
          _stat('Parties', '${n('games')}'),
          _stat('Victoires', '${n('wins')}'),
          _stat('Moyenne', p.average.fr(1)),
          _stat('Fléchettes', '${n('darts')}'),
          _stat('Meilleure fin', n('best_co') == 0 ? '–' : '${n('best_co')}'),
          _stat('Meilleure manche', '${n('high')}'),
          _stat('100+', '${n('n100')}'),
          _stat('180', '${n('n180')}'),
        ]),
        const TvSection('Cricket', padding: EdgeInsets.fromLTRB(0, 14, 0, 6)),
        _grid([
          _stat('Parties', '${n('cr_games')}'),
          _stat('Victoires', '${n('cr_wins')}'),
          _stat('MPR', (s['mpr'] as num?)?.fr(2) ?? '–'),
          _stat('Meilleure manche',
              n('cr_best') == 0 ? '–' : '${n('cr_best')} M'),
        ]),
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
                      '${practiceScoreText('${e.key}', (e.value as Map)['best'] as num? ?? 0)}',
                      style: Tv.title(15)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('open-stats'),
          onPressed: () =>
              openPlayerStats(context, id: p.key, name: p.name, color: p.color),
          icon: const Icon(Icons.insights),
          label: const Text('RANG DÉTAILLÉ, COURBE, PPR / MPR'),
        ),
      ],
    );
  }

  /// Un réglage : icône, titre, valeur actuelle, › — en bande de couleur.
  Widget _setting({
    Key? key,
    required Widget icon,
    required String title,
    required Color tint,
    Widget? value,
    VoidCallback? onTap,
  }) =>
      TileFx(
          seed: title,
          shine: .16,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: Band.deco(tint, r: 12),
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconTheme(
                              data: const IconThemeData(
                                  color: Colors.white, size: 20),
                              child: icon),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Band.text(Tv.title(15))),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                            child: DefaultTextStyle(
                              style: Band.text(Tv.label(14))
                                  .copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: value ?? const SizedBox(),
                            ),
                          ),
                          if (onTap != null)
                            const Icon(Icons.chevron_right,
                                color: Colors.white70, size: 20),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ));

  Widget _perso() {
    final owner = store.isOwner(p);
    // dégradé de haut en bas (dans l'ordre de lecture), RETIRER en rouge
    final n = 4 + (p.expired ? 1 : 0) + (p.expired ? 0 : 1);
    var k = 0;
    Color next() => Band.at(k++, n);
    final tReco = p.expired ? next() : null;
    final tColor = next();
    final tSound = p.expired ? null : next();
    final tBoard = next(), tPron = next(), tOwner = next();
    final items = <Widget>[
      if (p.expired)
        _setting(
          icon: const Icon(Icons.login),
          title: 'RECONNECTER',
          tint: tReco!,
          value: const Text('session expirée'),
          onTap: () => showAccountPage(context, pseudo: p.name),
        ),
      _setting(
        icon: ColorDot(p.color),
        title: 'COULEUR',
        tint: tColor,
        onTap: () => showColorSheet(context, p),
      ),
      if (!p.expired)
        ListenableBuilder(
          listenable: MediaStore.instance,
          builder: (context, _) {
            final s = MediaStore.instance.soundOf(p.key);
            return _setting(
              icon: const Icon(Icons.music_note),
              title: 'SON',
              tint: tSound!,
              value: Text(s.isEmpty
                  ? 'Aucun'
                  : s == kVoiceSound
                      ? 'Ma voix'
                      : kTurnSounds[s] ?? s),
              onTap: () => showTurnSoundSheet(context, p),
            );
          },
        ),
      ListenableBuilder(
        listenable: PlayerBoards.instance,
        builder: (context, _) => _setting(
          key: const ValueKey('player-board'),
          icon: const Icon(Icons.adjust),
          title: 'CIBLE',
          tint: tBoard,
          value: Text(PlayerBoards.instance.of(p.key)?.name ?? 'Par défaut'),
          onTap: () => showPlayerBoardSheet(context, p),
        ),
      ),
      ListenableBuilder(
        listenable: AudioService.instance,
        builder: (context, _) => _setting(
          key: const ValueKey('pronunciation'),
          icon: const Icon(Icons.record_voice_over),
          title: 'PRONONCIATION',
          tint: tPron,
          value: Text(AudioService.instance.spokenName(p.name)),
          onTap: _editPronunciation,
        ),
      ),
      _setting(
        icon: Icon(owner ? Icons.star : Icons.star_outline),
        title: 'PROFIL PRINCIPAL',
        tint: tOwner,
        value: Text(owner ? 'Oui' : 'Non'),
        onTap: owner ? null : () => store.setOwner(p),
      ),
      _setting(
        icon: const Icon(Icons.logout),
        title: 'RETIRER',
        tint: Band.danger,
        value: const Text('du téléphone'),
        onTap: _forget,
      ),
    ];
    return GridView(
      key: const ValueKey('pane-perso'),
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 60,
      ),
      children: items,
    );
  }

  Widget _games() {
    final recent = (p.profile?['recent'] as List?) ?? const [];
    return ListView(
      key: const ValueKey('pane-games'),
      padding: const EdgeInsets.fromLTRB(0, 4, 12, 12),
      children: [
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
            leading: Icon(g['won'] == true ? Icons.emoji_events : Icons.close,
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
        if (recent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => openPlayerStats(context,
                  id: p.key, name: p.name, color: p.color),
              icon: const Icon(Icons.history),
              label: const Text('TOUT L\'HISTORIQUE'),
            ),
          ),
      ],
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
                try {
                  await PlayerBoards.instance.set(p, sk);
                  TvLink.instance.refresh();
                } on ApiError catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
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
                    'Affichée pendant son tour, sur tous les téléphones, la TV et en ligne. Celle du profil principal reste sur l\'écran TV en attente. « Par défaut » = style choisi dans les options du téléphone.',
                    style: Tv.label(12)),
              ],
            ),
          );
        },
      ),
    );
