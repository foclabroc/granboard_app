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
import 'game_page.dart';
import 'players_page.dart' show RatingBadge;
import 'setup_page.dart';
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
  try {
    final room = await OnlineService.instance.answer(invite.id, accept);
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
          const SizedBox(height: 6),
          Text('$first commence · chacun chez soi sur sa cible',
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
    final game = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => SetupPage(online: [
                X01Player(id: me.key, name: me.name),
                X01Player(id: p.key, name: p.name),
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
      appBar: AppBar(toolbarHeight: 46, title: const Text('EN LIGNE')),
      body: TvBackground(
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
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _list()),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: _side(me)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list() {
    final ps = online.players;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvSection('Joueurs en ligne (${ps.length})',
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6)),
        Expanded(
          child: ps.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                        online.connected
                            ? 'Personne d\'autre pour l\'instant.\n'
                                'Les joueurs apparaissent ici dès qu\'ils '
                                'ouvrent Foclaboard.'
                            : online.error ?? 'Connexion…',
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

  Widget _playerRow(OnlinePlayer p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tv.line),
      ),
      child: Row(
        children: [
          PlayerAvatar(name: p.name, color: p.color, size: 40, id: p.key),
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
                      Icon(Icons.circle,
                          size: 9, color: p.busy ? Tv.gold : Tv.green),
                      const SizedBox(width: 5),
                      Text(p.busy ? 'EN PARTIE' : 'LIBRE', style: Tv.label(11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (p.rating != null) ...[
            RatingBadge(rating: p.rating!),
            const SizedBox(width: 8),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(96, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: p.busy ? null : () => _challenge(p),
            child: Text('DÉFIER', style: Tv.title(18, color: Colors.black)),
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
                          size: 9, color: online.connected ? Tv.green : Tv.red),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                            online.connected
                                ? 'EN LIGNE'
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
            '1 contre 1, chacun chez soi sur sa cible.\n'
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
