import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../board_service.dart';
import '../game/darts_game.dart';
import '../game/x01.dart';
import '../media.dart';
import '../online/online.dart';
import '../players.dart';
import '../server.dart';
import '../tv/tv_home.dart' show TvGameView;
import 'game_page.dart';
import 'players_page.dart' show RatingBadge;
import 'setup_page.dart';
import 'setup_widgets.dart';
import 'theme.dart';
import 'widgets.dart';
import 'stats_page.dart';

/// Ouvre la partie en ligne de la salle [roomId] (défi accepté ou reprise).
Future<void> openOnlineGame(BuildContext context, int roomId) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final room = await OnlineService.instance.openRoom(roomId);
    if (room.left) {
      room.close();
      messenger.showSnackBar(
          const SnackBar(content: Text('Cette partie est terminée')));
      OnlineService.instance.ping();
      return;
    }
    final game = gameFromJson(room.game);
    await nav.push(
        MaterialPageRoute(builder: (_) => GamePage(game: game, online: room)));
  } on ApiError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Défi envoyé (id [inviteId]) : attend la réponse de [p] puis ouvre la
/// partie (message en bas si refusé ou sans réponse).
Future<void> waitForAnswer(BuildContext context, int inviteId, OnlinePlayer p,
    Map<String, dynamic> game) async {
  final r = await showDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WaitDialog(inviteId: inviteId, player: p, game: game),
  );
  if (!context.mounted) return;
  if (r is int) {
    await openOnlineGame(context, r);
  } else if (r is String) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r)));
  }
}

/// Match de tournoi : « TOURNOI <nom> · FINALE » (null hors tournoi).
String? tournamentLine(Map<String, dynamic> game) {
  final tn = game['tn'];
  if (tn is! Map) return null;
  final rounds = (tn['rounds'] as num?)?.toInt() ?? 0;
  final r = (tn['r'] as num?)?.toInt() ?? 0;
  final left = rounds - r;
  final what = switch (left) {
    0 => 'FINALE',
    1 => 'DEMI-FINALE',
    2 => 'QUART DE FINALE',
    3 => 'HUITIÈME DE FINALE',
    _ => 'TOUR $r',
  };
  return 'TOURNOI ${'${tn['name'] ?? ''}'.toUpperCase()} · $what';
}

/// Nom et règles de la partie d'un défi.
(String, String, String) describeGame(Map<String, dynamic> json) {
  try {
    final g = gameFromJson(json);
    return (g.title, g.rulesLabel, g.players.first.name);
  } catch (_) {
    return ('Partie', '', '');
  }
}

/// Noms de l'équipe qui défie en double (« FOC ET CED »).
String _teamOf(OnlineInvite invite) {
  final home = invite.game['home'];
  final names = [
    for (final p in (invite.game['players'] as List? ?? const []))
      if (home is Map && home['${(p as Map)['id']}'] == 'a')
        '${p['name']}'.toUpperCase()
  ];
  return names.join(' ET ');
}

/// 1 contre 1 (faux) ou double (vrai) ; null = annulé.
Future<bool?> askDouble(BuildContext context, String opponent) =>
    showAppSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('DÉFIER ${opponent.toUpperCase()}',
                style: Tv.title(22, color: Tv.goldLight)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (dbl, icon, title, sub) in [
                  (false, Icons.person, '1 CONTRE 1', 'Toi contre $opponent'),
                  (
                    true,
                    Icons.groups,
                    '2 CONTRE 2',
                    'Toi et un équipier de chez toi contre $opponent et un '
                        'équipier de chez lui'
                  ),
                ]) ...[
                  if (dbl) const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: ValueKey(dbl ? 'mode-double' : 'mode-single'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, dbl),
                      child: Container(
                        height: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Tv.panel2,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Tv.gold.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 36, color: Tv.goldLight),
                            const SizedBox(height: 4),
                            Text(title, style: Tv.title(22)),
                            Text(sub,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Tv.label(11, color: Tv.text)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

/// Choix de mon équipier en double : un compte du téléphone (stats
/// envoyées) ou un invité. [side] = a (qui défie) ou b : l'invité reçoit
/// un id propre à ma maison (« guest-a1 »).
Future<X01Player?> pickTeammate(BuildContext context,
    {required String side,
    required PlayerProfile me,
    required Set<String> exclude}) {
  final store = PlayerStore.instance;
  final accounts = [
    for (final p in store.players)
      if (!exclude.contains(p.key) && !p.expired) p
  ];
  return showAppSheet<X01Player>(
    context,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TON ÉQUIPIER', style: Tv.title(22, color: Tv.goldLight)),
          Text('Il joue avec toi, chez toi, sur ta cible.',
              style: Tv.label(12, color: Tv.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in accounts)
                ActionChip(
                  key: ValueKey('mate-${p.key}'),
                  avatar: PlayerAvatar.of(p, size: 26),
                  label: Text(p.name.toUpperCase(), style: Tv.title(16)),
                  onPressed: () =>
                      Navigator.pop(ctx, X01Player(id: p.key, name: p.name)),
                ),
              ActionChip(
                key: const ValueKey('mate-guest'),
                avatar: const Icon(Icons.person_outline, size: 20),
                label: Text('INVITÉ (SANS STATS)', style: Tv.title(16)),
                onPressed: () => Navigator.pop(
                    ctx,
                    X01Player(
                        id: 'guest-${side}1', name: 'Invité de ${me.name}')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Fenêtre « X te défie » (affichée par l'accueil, par-dessus n'importe
/// quel écran). Se ferme seule si le défi est annulé ou expire.
Future<void> showInviteDialog(BuildContext context, OnlineInvite invite) async {
  AudioService.instance.play(Sfx.ton);
  AudioService.instance
    ..names = [invite.from.name]
    ..sayLater('${invite.from.name} te défie');
  final accept = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InviteDialog(invite: invite),
  );
  if (accept == null || !context.mounted) return;
  // Double : je choisis mon équipier avant d'entrer dans la partie
  Map<String, dynamic>? game;
  final me = OnlineService.instance.me;
  if (accept && invite.game['double'] == true && me != null) {
    final ids = {
      for (final p in (invite.game['players'] as List? ?? const []))
        '${(p as Map)['id']}'
    };
    final mate = await pickTeammate(context, side: 'b', me: me, exclude: ids);
    if (!context.mounted) return;
    if (mate == null) {
      // abandon du choix = refus
      OnlineService.instance.answer(invite.id, false).catchError((_) => null);
      return;
    }
    game = completeDouble(invite.game, me.key, mate);
  }
  try {
    final room =
        await OnlineService.instance.answer(invite.id, accept, game: game);
    if (room != null && context.mounted) await openOnlineGame(context, room);
  } on ApiError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _InviteDialog extends StatefulWidget {
  final OnlineInvite invite;
  const _InviteDialog({required this.invite});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final online = OnlineService.instance;

  @override
  void initState() {
    super.initState();
    online.addListener(_check);
    MediaStore.instance.ensure([widget.invite.from.key]);
  }

  @override
  void dispose() {
    online.removeListener(_check);
    super.dispose();
  }

  bool _done = false;

  /// Ferme la fenêtre une seule fois (réponse, ou défi disparu).
  void _close(bool? answer) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.pop(context, answer);
  }

  /// Défi annulé ou expiré : la fenêtre se ferme.
  void _check() {
    if (online.connected && online.invite?.id != widget.invite.id) {
      _close(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.invite.from;
    final (title, rules, first) = describeGame(widget.invite.game);
    return AlertDialog(
      title: Row(
        children: [
          PlayerAvatar(
              name: from.name, color: from.color, size: 44, id: from.key),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${from.name.toUpperCase()} TE DÉFIE',
                style: Tv.title(24, color: Tv.gold)),
          ),
          if (from.rating != null) RatingBadge(rating: from.rating!),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tournamentLine(widget.invite.game) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(tournamentLine(widget.invite.game)!,
                  style: Tv.title(16, color: Tv.gold)),
            ),
          Text(title.toUpperCase(), style: Tv.title(22)),
          if (rules.isNotEmpty)
            Text(rules.toUpperCase(), style: Tv.label(12, color: Tv.text)),
          if (widget.invite.game['double'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'EN DOUBLE : ${_teamOf(widget.invite)} · tu choisis ton '
                  'équipier en acceptant',
                  style: Tv.title(15, color: Tv.goldLight)),
            ),
          const SizedBox(height: 6),
          Text(
              widget.invite.game['double'] == true
                  ? 'Chaque équipe joue chez elle sur sa cible'
                  : '$first commence · chacun chez soi sur sa cible',
              style: Tv.label(12)),
          if (!BoardService.instance.isConnected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Ta cible n\'est pas connectée',
                  style: Tv.title(14, color: Tv.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => _close(false), child: const Text('REFUSER')),
        FilledButton.icon(
          onPressed: () => _close(true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('ACCEPTER'),
        ),
      ],
    );
  }
}

/// Écran « En ligne » : joueurs connectés, défi, reprise d'une partie.
class OnlinePage extends StatefulWidget {
  const OnlinePage({super.key});

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  final online = OnlineService.instance;

  @override
  void initState() {
    super.initState();
    online.watch();
  }

  @override
  void dispose() {
    online.unwatch();
    super.dispose();
  }

  Future<void> _challenge(OnlinePlayer p) async {
    final me = online.me;
    if (me == null) return;
    // 1 contre 1, ou double (2 contre 2, une maison par équipe)
    final double = await askDouble(context, p.name);
    if (double == null || !mounted) return;
    X01Player? mate;
    if (double) {
      mate = await pickTeammate(context,
          side: 'a', me: me, exclude: {me.key, p.key});
      if (mate == null || !mounted) return;
    }
    final game = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => SetupPage(online: [
                X01Player(id: me.key, name: me.name),
                X01Player(id: p.key, name: p.name),
                if (mate != null) mate,
              ])),
    );
    if (game == null || !mounted) return;
    int id;
    try {
      id = await online.challenge(p, game);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    await waitForAnswer(context, id, p, game);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SetupBand(title: 'En ligne', sub: 'Configuration'),
            Expanded(
              child: TvBackground(
                child: ListenableBuilder(
                  listenable: Listenable.merge([online, PlayerStore.instance]),
                  builder: (context, _) {
                    final me = online.me;
                    if (me == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              PlayerStore.instance.owner == null
                                  ? 'Crée d\'abord ton profil (Accueil › Joueurs) '
                                      'pour jouer en ligne.'
                                  : 'Reconnecte ton profil (Accueil › Joueurs) '
                                      'pour jouer en ligne.',
                              textAlign: TextAlign.center,
                              style: Tv.title(20)),
                        ),
                      );
                    }
                    final count = online.people.isNotEmpty
                        ? online.people.length
                        : online.players.length;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TableauPanel(
                                title: 'Joueurs ($count)', child: _list()),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TableauPanel(
                                title: 'Mon espace', child: _side(me)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filtre de la liste : all | friends | online.
  String _filter = 'all';
  String _query = '';

  Future<void> _friend(Future<void> Function() job) async {
    try {
      await job();
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Ami touché : le retirer (ou annuler ma demande) ?
  Future<void> _confirmRemove(OnlinePlayer p) async {
    final sent = p.friend == 'sent';
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sent ? 'Annuler la demande ?' : 'Retirer cet ami ?',
            style: Tv.title(22)),
        content: Text(sent
            ? 'Ta demande d\'ami à ${p.name} sera annulée.'
            : '${p.name} ne sera plus dans tes amis.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NON')),
          FilledButton(
              key: const ValueKey('friend-remove-yes'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(sent ? 'ANNULER LA DEMANDE' : 'RETIRER')),
        ],
      ),
    );
    if (yes == true) await _friend(() => online.removeFriend(p));
  }

  Widget _list() {
    // Tous les joueurs du serveur ; avant leur arrivée, ceux en ligne
    final all = online.people.isNotEmpty ? online.people : online.players;
    final q = _query.trim().toLowerCase();
    final ps = [
      for (final p in all)
        if ((_filter == 'all' ||
                (_filter == 'friends' && (p.isFriend || p.friend == 'ask')) ||
                (_filter == 'online' && !p.offline)) &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
          p
    ];
    final here = all.where((p) => !p.offline).length;
    final friends = all.where((p) => p.isFriend).length;
    Widget chip(String id, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            key: ValueKey('people-$id'),
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
            selected: _filter == id,
            label: Text(label),
            onSelected: (_) => setState(() => _filter = id),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    chip('all', 'TOUS (${all.length})'),
                    chip('online', 'EN LIGNE ($here)'),
                    chip('friends', 'AMIS ($friends)'),
                  ]),
                ),
              ),
              SizedBox(
                width: 120,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    key: const ValueKey('people-search'),
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Chercher',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 32, minHeight: 0),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ps.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                        !online.connected
                            ? online.error ?? 'Connexion…'
                            : q.isNotEmpty
                                ? 'Aucun joueur trouvé.'
                                : _filter == 'friends'
                                    ? 'Pas encore d\'ami.\nTouche + AMI à '
                                        'côté d\'un joueur pour lui demander.'
                                    : _filter == 'online'
                                        ? 'Personne d\'autre en ligne pour '
                                            'l\'instant.'
                                        : 'Aucun autre joueur sur le serveur '
                                            'pour l\'instant.',
                        textAlign: TextAlign.center,
                        style: Tv.label(14, color: Tv.text)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  itemCount: ps.length,
                  itemBuilder: (context, i) => _playerRow(ps[i]),
                ),
        ),
      ],
    );
  }

  /// Regarde la partie en ligne d'un ami.
  Future<void> _watch(OnlinePlayer p) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => WatchPage(player: p)));
  }

  /// Propose un rendez-vous à [p] (jour puis heure).
  Future<void> _date(OnlinePlayer p) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'RENDEZ-VOUS AVEC ${p.name.toUpperCase()}',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (now.hour + 1) % 24, minute: 0),
      helpText: 'À QUELLE HEURE ?',
    );
    if (time == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    await _friend(() => online.proposeDate(p, at));
  }

  Future<void> _confirmBlock(OnlinePlayer p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bloquer ${p.name} ?', style: Tv.title(22)),
        content: const Text(
            'Il ne pourra plus te défier ni te demander en ami, et te verra '
            'hors ligne. Tu pourras le débloquer ici.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NON')),
          FilledButton(
              key: const ValueKey('block-yes'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('BLOQUER')),
        ],
      ),
    );
    if (yes == true) await _friend(() => online.block(p));
  }

  /// Menu d'une ligne : tout ce qu'on peut faire avec ce joueur.
  Widget _menu(OnlinePlayer p) {
    return PopupMenuButton<String>(
      key: ValueKey('person-menu-${p.id}'),
      tooltip: 'Plus',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: Tv.muted),
      onSelected: (v) {
        switch (v) {
          case 'stats':
            openPlayerStats(context, id: p.key, name: p.name, color: p.color);
          case 'friend':
            p.friend == ''
                ? _friend(() => online.askFriend(p))
                : _confirmRemove(p);
          case 'want':
            _friend(() => online.want(p, !p.wanted));
          case 'date':
            _date(p);
          case 'watch':
            _watch(p);
          case 'block':
            p.blocked ? _friend(() => online.block(p, false)) : _confirmBlock(p);
        }
      },
      itemBuilder: (_) => [
        if (p.title.isNotEmpty || p.motto.isNotEmpty)
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.title.isNotEmpty)
                  Text(p.title.toUpperCase(),
                      style: Tv.label(13, color: Tv.gold)),
                if (p.motto.isNotEmpty)
                  Text('« ${p.motto} »',
                      style: const TextStyle(
                          color: Tv.text, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        const PopupMenuItem(value: 'stats', child: Text('Stats et rang')),
        if (!p.blocked) ...[
          if (p.friend == '')
            const PopupMenuItem(
                value: 'friend', child: Text('Demander en ami')),
          if (p.friend == 'sent')
            const PopupMenuItem(
                value: 'friend', child: Text('Annuler ma demande d\'ami')),
          if (p.isFriend)
            const PopupMenuItem(value: 'friend', child: Text('Retirer cet ami')),
          PopupMenuItem(
              value: 'want',
              child: Text(p.wanted
                  ? 'Retirer « je veux jouer »'
                  : 'Lui dire que je veux jouer')),
          const PopupMenuItem(
              value: 'date', child: Text('Proposer un rendez-vous')),
          if (p.watchable)
            const PopupMenuItem(
                value: 'watch', child: Text('Regarder sa partie')),
        ],
        PopupMenuItem(
            value: 'block', child: Text(p.blocked ? 'Débloquer' : 'Bloquer')),
      ],
    );
  }

  /// Bouton d'amitié d'une ligne, selon le lien.
  Widget _friendButton(OnlinePlayer p) {
    switch (p.friend) {
      case 'blocked':
        return const SizedBox.shrink();
      case 'ok':
        return IconButton(
          key: ValueKey('friend-ok-${p.id}'),
          tooltip: 'Ami (toucher pour retirer)',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.star, color: Tv.gold),
          onPressed: () => _confirmRemove(p),
        );
      case 'sent':
        return TextButton(
          key: ValueKey('friend-sent-${p.id}'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          onPressed: () => _confirmRemove(p),
          child: Text('DEMANDÉ', style: Tv.label(12)),
        );
      case 'ask':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('friend-no-${p.id}'),
              tooltip: 'Refuser',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, color: Tv.red),
              onPressed: () => _friend(() => online.answerFriend(p, false)),
            ),
            OutlinedButton(
              key: ValueKey('friend-yes-${p.id}'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              onPressed: () => _friend(() => online.answerFriend(p, true)),
              child: Text('ACCEPTER', style: Tv.title(15, color: Tv.green)),
            ),
          ],
        );
      default:
        return TextButton.icon(
          key: ValueKey('friend-add-${p.id}'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          onPressed: () => _friend(() => online.askFriend(p)),
          icon: const Icon(Icons.person_add_alt_1, size: 16),
          label: Text('AMI', style: Tv.label(12, color: Tv.text)),
        );
    }
  }

  /// Bouton principal d'une ligne : défier, regarder, prévenir, débloquer.
  Widget _mainButton(OnlinePlayer p) {
    final style = FilledButton.styleFrom(
        minimumSize: const Size(92, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8));
    if (p.blocked) {
      return OutlinedButton(
        key: ValueKey('unblock-${p.id}'),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(92, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: () => _friend(() => online.block(p, false)),
        child: Text('DÉBLOQUER', style: Tv.title(15)),
      );
    }
    if (p.free) {
      return FilledButton(
        style: style,
        onPressed: () => _challenge(p),
        child: Text('DÉFIER', style: Tv.title(18, color: Colors.black)),
      );
    }
    if (p.watchable) {
      return FilledButton.tonal(
        key: ValueKey('watch-${p.id}'),
        style: style,
        onPressed: () => _watch(p),
        child: Text('REGARDER', style: Tv.title(16)),
      );
    }
    // Absent, en partie ou « ne pas déranger » : lui laisser un mot
    return OutlinedButton(
      key: ValueKey('want-${p.id}'),
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(92, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8)),
      onPressed: () => _friend(() => online.want(p, !p.wanted)),
      child: Text(p.wanted ? 'PRÉVENU ✓' : 'PRÉVENIR',
          style: Tv.title(15, color: p.wanted ? Tv.green : Tv.text)),
    );
  }

  Widget _playerRow(OnlinePlayer p) {
    final ask = p.friend == 'ask';
    final (dot, base) = p.blocked
        ? (Tv.red, 'BLOQUÉ')
        : p.offline
            ? (
                Tv.muted,
                p.seen == null
                    ? 'HORS LIGNE'
                    : 'VU ${agoText(p.seen!).toUpperCase()}'
              )
            : p.busy
                ? (Tv.gold, 'EN PARTIE')
                : p.dnd
                    ? (Tv.red, 'NE PAS DÉRANGER')
                    : (Tv.green, 'LIBRE');
    final note = ask
        ? 'TE DEMANDE EN AMI'
        : p.want
            ? 'VEUT JOUER AVEC TOI'
            : p.isFriend && p.wins + p.losses > 0
                ? '${p.wins} V · ${p.losses} D'
                : null;
    final hot = ask || p.want;
    return Container(
      key: ValueKey('person-${p.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hot ? Tv.green : Tv.line),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: p.offline || p.blocked ? 0.55 : 1,
            child:
                PlayerAvatar(name: p.name, color: p.color, size: 40, id: p.key),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => openPlayerStats(context,
                  id: p.key, name: p.name, color: p.color),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(20)),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 9, color: dot),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(note == null ? base : '$base · $note',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tv.label(11, color: hot ? Tv.green : null)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (p.rating != null) ...[
            RatingBadge(rating: p.rating!),
            const SizedBox(width: 4),
          ],
          _friendButton(p),
          const SizedBox(width: 4),
          _mainButton(p),
          _menu(p),
        ],
      ),
    );
  }

  /// Phrase de mon profil : la changer.
  Future<void> _editMotto() async {
    final ctl = TextEditingController(text: online.motto);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ma phrase', style: Tv.title(22)),
        content: TextField(
          key: const ValueKey('motto-field'),
          controller: ctl,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
              hintText: 'Visible par les autres joueurs'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER')),
          FilledButton(
              key: const ValueKey('motto-ok'),
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (v != null) await _friend(() => online.setMotto(v));
  }

  String _dateText(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    const days = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return '${days[t.weekday - 1]} ${two(t.day)}/${two(t.month)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  /// Mes rendez-vous (panneau de droite).
  Widget _dateRow(OnlineDate d) {
    final wait = !d.ok && !d.mine; // à moi de répondre
    return Container(
      key: ValueKey('date-${d.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
      decoration: BoxDecoration(
        color: Tv.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: wait ? Tv.green : Tv.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_dateText(d.at)} · ${d.other.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(15)),
                Text(
                    d.ok
                        ? 'RENDEZ-VOUS PRIS'
                        : d.mine
                            ? 'EN ATTENTE DE SA RÉPONSE'
                            : 'TE PROPOSE CE RENDEZ-VOUS',
                    style: Tv.label(10,
                        color: d.ok || wait ? Tv.green : null)),
              ],
            ),
          ),
          if (wait)
            IconButton(
              key: ValueKey('date-yes-${d.id}'),
              tooltip: 'Accepter',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.check, color: Tv.green),
              onPressed: () => _friend(() => online.answerDate(d.id, true)),
            ),
          IconButton(
            key: ValueKey('date-no-${d.id}'),
            tooltip: wait ? 'Refuser' : 'Retirer',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, color: Tv.muted),
            onPressed: () => _friend(() => online.answerDate(d.id, false)),
          ),
        ],
      ),
    );
  }

  Widget _side(PlayerProfile me) {
    final room = online.resumeRoom;
    final board = BoardService.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      children: [
        Row(
          children: [
            PlayerAvatar.of(me, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(20)),
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 9,
                          color: !online.connected || online.dnd
                              ? Tv.red
                              : Tv.green),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                            online.connected
                                ? [
                                    online.dnd ? 'NE PAS DÉRANGER' : 'EN LIGNE',
                                    if (online.title.isNotEmpty)
                                      online.title.toUpperCase()
                                  ].join(' · ')
                                : (online.error ?? 'CONNEXION…').toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tv.label(11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        InkWell(
          key: const ValueKey('motto-edit'),
          onTap: _editMotto,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      online.motto.isEmpty
                          ? 'Ajouter une phrase à mon profil'
                          : '« ${online.motto} »',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: online.motto.isEmpty ? Tv.muted : Tv.text,
                          fontStyle: FontStyle.italic,
                          fontSize: 13)),
                ),
                Icon(Icons.edit, size: 14, color: Tv.muted),
              ],
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('dnd'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          title: Text('NE PAS DÉRANGER', style: Tv.label(13, color: Tv.text)),
          subtitle: Text('Visible en ligne, sans recevoir de défi',
              style: TextStyle(color: Tv.muted, fontSize: 11)),
          value: online.dnd,
          onChanged: (v) => _friend(() => online.setDnd(v)),
        ),
        if (online.dates.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text('RENDEZ-VOUS', style: Tv.label(12, color: Tv.gold)),
          ),
          for (final d in online.dates) _dateRow(d),
        ],
        if (room != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: () => openOnlineGame(context, room),
            icon: const Icon(Icons.replay),
            label: Text('REPRENDRE LA PARTIE',
                style: Tv.title(18, color: Colors.black)),
          ),
        ],
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: board,
          builder: (context, _) => board.isConnected
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      'Cible non connectée : connecte-la avant de '
                      'jouer.',
                      style: Tv.title(14, color: Tv.red)),
                ),
        ),
        Text(
            'Tous les joueurs du serveur sont listés : + AMI pour demander '
            'quelqu\'un en ami, l\'étoile pour le retirer, PRÉVENIR pour '
            'dire à un absent que tu veux jouer, les 3 points pour le reste '
            '(rendez-vous, regarder la partie d\'un ami, bloquer).\n'
            '1 contre 1 ou 2 contre 2, chacun chez soi sur sa cible.\n'
            'Touche DÉFIER, choisis le jeu : ton adversaire a 45 s pour '
            'accepter.\n'
            'Pendant la partie, vous vous voyez en vidéo : touche l\'image '
            'pour couper la caméra ou le micro, ou passer à la caméra '
            'arrière.',
            style: Tv.label(13, color: Tv.text)),
      ],
    );
  }
}

/// « En attente de X… » après un défi envoyé. Renvoie l'id de la salle
/// (accepté), un message (refusé, expiré) ou null (annulé).
class _WaitDialog extends StatefulWidget {
  final int inviteId;
  final OnlinePlayer player;
  final Map<String, dynamic> game;
  const _WaitDialog(
      {required this.inviteId, required this.player, required this.game});

  @override
  State<_WaitDialog> createState() => _WaitDialogState();
}

class _WaitDialogState extends State<_WaitDialog> {
  final online = OnlineService.instance;
  Timer? _timeout;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    online.addListener(_check);
    // Secours si le serveur ne répond plus
    _timeout = Timer(const Duration(seconds: 55), () {
      online.cancel(widget.inviteId);
      _close('${widget.player.name} n\'a pas répondu');
    });
  }

  @override
  void dispose() {
    online.removeListener(_check);
    _timeout?.cancel();
    super.dispose();
  }

  void _close(Object? result) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.pop(context, result);
  }

  void _check() {
    final s = online.sent;
    if (s == null || s.id != widget.inviteId) return;
    switch (s.status) {
      case 'accepted':
        if (s.room != null) _close(s.room);
      case 'declined':
        _close('${widget.player.name} a refusé le défi');
      case 'expired':
        _close('${widget.player.name} n\'a pas répondu');
      case 'cancelled':
        _close(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final (title, rules, _) = describeGame(widget.game);
    return AlertDialog(
      title: Row(
        children: [
          PlayerAvatar(name: p.name, color: p.color, size: 40, id: p.key),
          const SizedBox(width: 12),
          Expanded(
            child: Text('DÉFI ENVOYÉ À ${p.name.toUpperCase()}',
                style: Tv.title(22, color: Tv.gold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tournamentLine(widget.game) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(tournamentLine(widget.game)!,
                  style: Tv.title(15, color: Tv.gold)),
            ),
          Text(title.toUpperCase(), style: Tv.title(20)),
          if (rules.isNotEmpty)
            Text(rules.toUpperCase(), style: Tv.label(12, color: Tv.text)),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text('En attente de sa réponse…', style: Tv.label(12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            online.cancel(widget.inviteId);
            _close(null);
          },
          child: const Text('ANNULER'),
        ),
      ],
    );
  }
}

/// Partie en ligne d'un ami, regardée en direct (comme sur un écran).
class WatchPage extends StatefulWidget {
  final OnlinePlayer player;
  const WatchPage({super.key, required this.player});

  /// Relecture de la partie (coupée dans les tests).
  static Duration every = const Duration(seconds: 2);

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final online = OnlineService.instance;
  Map<String, dynamic>? _state;
  String? _over;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(WatchPage.every, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _over != null) return;
    _busy = true;
    try {
      final g = await online.watchGame(widget.player.id);
      if (!mounted) return;
      if (g == null) {
        setState(() => _over = _state == null
            ? '${widget.player.name} n\'est plus en partie.'
            : 'Partie terminée.');
        _timer?.cancel();
        return;
      }
      final ids = [
        for (final p in (g['players'] as List? ?? const []))
          '${(p as Map)['id']}'
      ];
      if (_state == null) {
        PlayerStore.instance.setGameColors(ids);
        MediaStore.instance.ensure(ids);
      }
      final old = _state?['game'] as Map?;
      if (old == null ||
          '${old['actions']}' != '${g['actions']}' ||
          '${old['players']}' != '${g['players']}') {
        setState(() => _state = {'game': g});
      }
    } on ApiError catch (e) {
      if (mounted && _state == null) setState(() => _over = e.message);
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _state;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: st == null
                ? Center(
                    child: Text(_over ?? 'Connexion à la partie…',
                        style: Tv.title(22)))
                : TvGameView(state: st),
          ),
          if (_over != null && st != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Tv.gold)),
                  child: Text(_over!.toUpperCase(),
                      style: Tv.label(13, color: Tv.gold)),
                ),
              ),
            ),
          Positioned(
            left: 4,
            bottom: 4,
            child: SafeArea(
              child: TextButton.icon(
                key: const ValueKey('watch-quit'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text('QUITTER', style: Tv.label(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
