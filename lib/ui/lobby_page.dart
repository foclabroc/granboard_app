import 'dart:async';

import 'package:flutter/material.dart';

import '../board_service.dart';
import '../game/darts_game.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import '../online/online.dart';
import '../players.dart';
import '../server.dart';
import 'online_page.dart' show openOnlineGame;
import 'setup_page.dart';
import 'setup_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

/// Joueurs au plus dans une partie de salon (10 au Cricket).
int salonMaxPlayers(Map<String, dynamic> game) =>
    game['kind'] == 'cricket' ? 10 : 8;

/// Le jeu choisi peut-il se jouer avec [n] joueurs ? Message sinon.
String? salonProblem(Map<String, dynamic>? game, int n) {
  if (game == null) return 'L\'hôte doit choisir le jeu';
  final max = salonMaxPlayers(game);
  if (n > max) return '$max joueurs au plus pour ce jeu ($n dans le salon)';
  if (game['kind'] == 'practice') {
    try {
      final s = PracticeSettings.fromJson(
          Map<String, dynamic>.from(game['settings'] as Map));
      final i = kPracticeInfo[s.kind]!;
      if (n < i.minPlayers) {
        return '${i.name} : ${i.minPlayers} joueurs minimum';
      }
      if (n > i.maxPlayers) {
        return '${i.name} : ${i.maxPlayers} joueurs maximum';
      }
    } catch (_) {}
  }
  return null;
}

/// Crée un salon (public ou privé) puis l'ouvre.
Future<void> createLobby(BuildContext context) async {
  final public = await showAppSheet<bool>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('NOUVEAU SALON', style: Tv.title(22, color: Tv.goldLight)),
          Text(
              '2 à $kLobbyHomes maisons, chacune sur sa cible avec ses joueurs.',
              style: Tv.label(12, color: Tv.text)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (pub, icon, title, sub) in [
                (false, Icons.lock, 'PRIVÉ', 'Sur invitation seulement'),
                (
                  true,
                  Icons.public,
                  'PUBLIC',
                  'Visible par tous dans la liste'
                ),
              ]) ...[
                if (pub) const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    key: ValueKey(pub ? 'lobby-public' : 'lobby-private'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, pub),
                    child: Container(
                      height: 120,
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
                          Icon(icon, size: 34, color: Tv.goldLight),
                          const SizedBox(height: 4),
                          Text(title, style: Tv.title(22)),
                          Text(sub,
                              textAlign: TextAlign.center,
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
  if (public == null || !context.mounted) return;
  try {
    final lobby = await OnlineService.instance.createLobby(public);
    if (context.mounted) await openLobby(context, lobby);
  } on ApiError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Rejoint le salon [id] (public ou invitation ; le mien : simplement
/// rouvert) puis l'ouvre.
Future<void> joinLobby(BuildContext context, int id) async {
  try {
    final s = OnlineService.instance;
    final lobby = s.lobby == id ? await s.openLobby(id) : await s.joinLobby(id);
    if (context.mounted) await openLobby(context, lobby);
  } on ApiError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    OnlineService.instance.ping();
  }
}

Future<void> openLobby(BuildContext context, Lobby lobby) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => LobbyPage(lobby: lobby)));

/// Fenêtre « X t'invite dans son salon » (affichée par l'accueil).
Future<void> showLobbyInviteDialog(BuildContext context, LobbyCard l) async {
  final who = (l.from ?? l.host).name;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$who t\'invite dans son salon', style: Tv.title(22)),
      content:
          Text('${l.homes} maison${l.homes > 1 ? 's' : ''}, ${l.players} joueur'
              '${l.players > 1 ? 's' : ''}'
              '${l.label.isEmpty ? '' : ' · ${l.label}'}.\n'
              'Chacun joue chez soi sur sa cible.'),
      actions: [
        TextButton(
            key: const ValueKey('lobby-invite-no'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non merci')),
        FilledButton(
            key: const ValueKey('lobby-invite-yes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejoindre')),
      ],
    ),
  );
  if (ok == null || !context.mounted) return;
  if (!ok) {
    OnlineService.instance.declineLobby(l.id);
    return;
  }
  await joinLobby(context, l.id);
}

/// Choix des joueurs de ma maison : comptes du téléphone (stats
/// envoyées) et invités, 4 au plus.
Future<List<X01Player>?> pickHomePlayers(
    BuildContext context, PlayerProfile me, List<X01Player> current) {
  final store = PlayerStore.instance;
  final chosen = [...current];
  return showAppSheet<List<X01Player>>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      bool has(String id) => chosen.any((p) => p.id == id);
      void toggle(X01Player p) => set(() {
            if (has(p.id)) {
              chosen.removeWhere((x) => x.id == p.id);
            } else if (chosen.length < kLobbyHomePlayers) {
              chosen.add(p);
            }
          });
      void addGuest() {
        if (chosen.length >= kLobbyHomePlayers) return;
        var n = 1;
        while (has('guest-${me.id}-$n')) {
          n++;
        }
        set(() => chosen.add(X01Player(
            id: 'guest-${me.id}-$n', name: 'Invité $n de ${me.name}')));
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JOUEURS DE MA MAISON',
                style: Tv.title(22, color: Tv.goldLight)),
            Text(
                'Ils jouent chez toi, sur ta cible '
                '($kLobbyHomePlayers au plus).',
                style: Tv.label(12, color: Tv.text)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in store.players)
                  if (!p.expired)
                    FilterChip(
                      key: ValueKey('home-${p.key}'),
                      selected: has(p.key),
                      avatar: PlayerAvatar.of(p, size: 24),
                      label: Text(p.name.toUpperCase(), style: Tv.title(15)),
                      onSelected: (_) =>
                          toggle(X01Player(id: p.key, name: p.name)),
                    ),
                for (final p in chosen)
                  if (p.id.startsWith('guest-'))
                    InputChip(
                      key: ValueKey('home-${p.id}'),
                      label: Text(p.name.toUpperCase(), style: Tv.title(15)),
                      onDeleted: () => toggle(p),
                    ),
                ActionChip(
                  key: const ValueKey('home-guest'),
                  avatar: const Icon(Icons.person_add_alt, size: 20),
                  label: Text('INVITÉ (SANS STATS)', style: Tv.title(15)),
                  onPressed:
                      chosen.length < kLobbyHomePlayers ? addGuest : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('home-ok'),
                onPressed:
                    chosen.isEmpty ? null : () => Navigator.pop(ctx, chosen),
                child: Text('VALIDER (${chosen.length})',
                    style: Tv.title(20, color: Colors.black)),
              ),
            ),
          ],
        ),
      );
    }),
  );
}

/// Salon : les maisons et leurs joueurs à gauche, la partie à droite
/// (jeu choisi par l'hôte, inviter, lancer). La partie s'ouvre chez tout
/// le monde au lancement ; après la partie, on revient ici.
class LobbyPage extends StatefulWidget {
  final Lobby lobby;
  const LobbyPage({super.key, required this.lobby});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  Lobby get lobby => widget.lobby;
  final online = OnlineService.instance;
  int? _opened;
  bool _busy = false;

  /// Une partie est ouverte par-dessus le salon : pas d'autre en même temps.
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    lobby.addListener(_changed);
    lobby.listen();
    online.watch();
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    lobby.removeListener(_changed);
    lobby.close();
    online.unwatch();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (lobby.gone) {
      lobby.removeListener(_changed);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu n\'es plus dans ce salon')));
      Navigator.pop(context);
      return;
    }
    final room = lobby.room;
    if (lobby.started && room != null && room != _opened && !_playing) {
      _opened = room;
      _play(room);
    }
    setState(() {});
  }

  Future<void> _play(int room) async {
    if (_playing) return;
    _playing = true;
    try {
      await openOnlineGame(context, room);
    } finally {
      _playing = false;
    }
    if (!mounted) return;
    // L'hôte a déjà relancé une autre partie (on jouait encore) : on la
    // rejoint au lieu de rouvrir le salon
    await lobby.fetch();
    final next = lobby.room;
    if (!mounted) return;
    if (lobby.started && next != null && next != room) {
      _opened = next;
      _play(next);
      return;
    }
    // Partie finie ou quittée : le salon se rouvre pour tout le monde
    await lobby.back();
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPlayers() async {
    final me = lobby.account;
    final ps = await pickHomePlayers(context, me,
        lobby.mine?.players ?? [X01Player(id: me.key, name: me.name)]);
    if (ps == null || !mounted) return;
    await _run(() => lobby.setPlayers(ps));
  }

  Future<void> _chooseGame() async {
    final players = lobby.allPlayers;
    final game = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => SetupPage(online: players, salon: true)),
    );
    if (game == null || !mounted) return;
    await _run(() => lobby.setGame(game));
  }

  Future<void> _start() async {
    final game = lobby.buildGame();
    final problem = salonProblem(game, lobby.allPlayers.length);
    if (game == null || problem != null) return;
    try {
      gameFromJson(game); // partie lisible
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisis à nouveau le jeu')));
      return;
    }
    await _run(() async {
      final room = await lobby.start(game);
      if (mounted && _opened != room) {
        _opened = room;
        _play(room);
      }
    });
  }

  Future<void> _invite() async {
    final inLobby = {
      for (final m in lobby.members) m.player.id,
      for (final (p, s) in lobby.invited)
        if (s == 'pending') p.id,
    };
    await showAppSheet<void>(
      context,
      builder: (ctx) => ListenableBuilder(
        listenable: online,
        builder: (ctx, _) {
          final free = [
            for (final p in online.players)
              if (!inLobby.contains(p.id) && !p.dnd && !p.blocked) p
          ];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVITER', style: Tv.title(22, color: Tv.goldLight)),
                Text('Joueurs en ligne en ce moment.',
                    style: Tv.label(12, color: Tv.text)),
                const SizedBox(height: 10),
                if (free.isEmpty)
                  Text('Personne d\'autre en ligne pour l\'instant.',
                      style: Tv.title(16, color: Tv.muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in free)
                        ActionChip(
                          key: ValueKey('invite-${p.id}'),
                          avatar: PlayerAvatar(
                              name: p.name,
                              color: p.color,
                              size: 24,
                              id: p.key),
                          label: Text(
                              '${p.name.toUpperCase()}${p.busy ? ' (EN PARTIE)' : ''}',
                              style: Tv.title(15)),
                          onPressed: () {
                            inLobby.add(p.id);
                            Navigator.pop(ctx);
                            _run(() => lobby.invite(p));
                          },
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quitter le salon ?', style: Tv.title(22)),
        content: Text(lobby.isHost && lobby.members.length > 1
            ? 'Le salon reste ouvert : ${lobby.members[1].player.name} '
                'devient l\'hôte.'
            : 'Les autres seront prévenus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Rester')),
          FilledButton(
              key: const ValueKey('lobby-leave-ok'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final host = lobby.host;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmLeave() || !mounted) return;
        lobby.removeListener(_changed);
        lobby.leave();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        body: SafeArea(
          left: false,
          right: false,
          child: Column(
            children: [
              SetupBand(
                title: 'Salon',
                sub: [
                  lobby.public ? 'Public' : 'Privé',
                  if (host != null) 'hôte ${host.name}',
                ].join(' · '),
              ),
              Expanded(
                child: SidePad(
                  child: TvBackground(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TableauPanel(
                              title:
                                  'Maisons (${lobby.members.length}/$kLobbyHomes)',
                              child: _homes(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child:
                                TableauPanel(title: 'Partie', child: _game()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _homes() {
    final me = lobby.account;
    final waiting = [
      for (final (p, s) in lobby.invited) (p, s),
    ];
    final free = kLobbyHomes - lobby.members.length - waiting.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      children: [
        for (final (i, m) in lobby.members.indexed)
          _homeRow(i, m, m.player.id == me.id),
        for (final (p, s) in waiting)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Opacity(
                  opacity: 0.5,
                  child: PlayerAvatar(
                      name: p.name, color: p.color, size: 34, id: p.key),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      '${p.name.toUpperCase()} · '
                      '${s == 'declined' ? 'A REFUSÉ' : 'INVITÉ…'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(16,
                          color: s == 'declined' ? Tv.red : Tv.muted)),
                ),
              ],
            ),
          ),
        for (var i = 0; i < free; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 17,
                    backgroundColor: Tv.panel2,
                    child: Icon(Icons.add, size: 18, color: Tv.muted)),
                const SizedBox(width: 10),
                Text('PLACE LIBRE', style: Tv.title(16, color: Tv.muted)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _homeRow(int i, LobbyMember m, bool mine) {
    final isHost = m.player.id == lobby.hostId;
    return Container(
      key: ValueKey('home-row-${m.player.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: mine ? Tv.gold.withValues(alpha: 0.10) : Tv.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mine ? Tv.gold : Tv.line),
      ),
      child: Row(
        children: [
          PlayerAvatar(
              name: m.player.name,
              color: m.player.color,
              size: 38,
              id: m.player.key),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                          'MAISON ${i + 1} · ${m.player.name.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.title(17)),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      Text('HÔTE', style: Tv.label(11, color: Tv.gold)),
                    ],
                    if (m.age >= 15) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.wifi_off, size: 14, color: Tv.red),
                    ],
                  ],
                ),
                Text(m.players.map((p) => p.name).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.label(12, color: Tv.text)),
              ],
            ),
          ),
          if (mine)
            IconButton(
              key: const ValueKey('home-edit'),
              tooltip: 'Joueurs de ma maison',
              onPressed: _busy || lobby.started ? null : _editPlayers,
              icon: const Icon(Icons.group_add),
            )
          else if (lobby.isHost && !lobby.started)
            IconButton(
              key: ValueKey('home-kick-${m.player.id}'),
              tooltip: 'Retirer du salon',
              onPressed: _busy ? null : () => _run(() => lobby.kick(m.player)),
              icon: Icon(Icons.close, color: Tv.muted),
            ),
        ],
      ),
    );
  }

  Widget _game() {
    final g = lobby.game;
    final n = lobby.allPlayers.length;
    final problem = lobby.members.length < 2
        ? 'Il faut au moins 2 maisons'
        : salonProblem(g, n);
    final label = '${g?['label'] ?? ''}';
    final board = BoardService.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      children: [
        Text(g == null ? 'JEU PAS ENCORE CHOISI' : label.toUpperCase(),
            style: Tv.title(22, color: g == null ? Tv.muted : Tv.goldLight)),
        if (g != null)
          Text(
              g['order'] == 'random'
                  ? 'Ordre tiré au hasard'
                  : 'Maisons en alternance',
              style: Tv.label(12, color: Tv.text)),
        const SizedBox(height: 8),
        if (lobby.started)
          FilledButton.icon(
            key: const ValueKey('lobby-rejoin'),
            onPressed: () {
              final r = lobby.room;
              if (r != null) _play(r);
            },
            icon: const Icon(Icons.play_arrow),
            label: Text('PARTIE EN COURS : REJOINDRE',
                style: Tv.title(16, color: Colors.black)),
          )
        else ...[
          if (lobby.isHost) ...[
            OutlinedButton.icon(
              key: const ValueKey('lobby-choose'),
              onPressed: _busy ? null : _chooseGame,
              icon: const Icon(Icons.tune),
              label: Text(g == null ? 'CHOISIR LE JEU' : 'CHANGER LE JEU',
                  style: Tv.title(16)),
            ),
            SwitchListTile(
              key: const ValueKey('lobby-public-switch'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text('SALON PUBLIC', style: Tv.label(13, color: Tv.text)),
              subtitle: Text('Visible par tous dans la liste des salons',
                  style: TextStyle(color: Tv.muted, fontSize: 11)),
              value: lobby.public,
              onChanged: _busy
                  ? null
                  : (v) => _run(() => lobby.setGame(null, public: v)),
            ),
          ],
          OutlinedButton.icon(
            key: const ValueKey('lobby-invite'),
            onPressed: _busy || lobby.full ? null : _invite,
            icon: const Icon(Icons.person_add),
            label: Text('INVITER', style: Tv.title(16)),
          ),
          const SizedBox(height: 10),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(problem, style: Tv.title(14, color: Tv.red)),
            ),
          if (lobby.isHost)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('lobby-start'),
                onPressed: problem == null && !_busy ? _start : null,
                icon: const Icon(Icons.play_arrow),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('LANCER ($n JOUEURS)',
                      style: Tv.title(22, color: Colors.black)),
                ),
              ),
            )
          else
            Text(
                '${lobby.host?.name ?? 'L\'hôte'} lance la partie quand '
                'tout le monde est prêt.',
                style: Tv.title(15, color: Tv.text)),
        ],
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: board,
          builder: (context, _) => board.isConnected
              ? const SizedBox.shrink()
              : Text('Cible non connectée : connecte-la avant de jouer.',
                  style: Tv.title(14, color: Tv.red)),
        ),
        const SizedBox(height: 8),
        Text(
            'Chaque maison joue chez elle, sur sa cible, pour ses joueurs ; '
            'tout le monde se voit en vidéo. Si une maison quitte la partie, '
            'ses joueurs passent leur tour.',
            style: Tv.label(12, color: Tv.text)),
      ],
    );
  }
}

/// Encart « Salons » de l'écran En ligne : créer, salons publics,
/// invitations, mon salon.
class LobbiesBox extends StatelessWidget {
  const LobbiesBox({super.key});

  @override
  Widget build(BuildContext context) {
    final online = OnlineService.instance;
    return ListenableBuilder(
      listenable: online,
      builder: (context, _) {
        final mine = online.lobby;
        final cards = [
          ...online.lobbyInvites,
          for (final l in online.lobbies)
            if (!online.lobbyInvites.any((i) => i.id == l.id)) l,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text('SALONS (2 À $kLobbyHomes CIBLES)',
                  style: Tv.label(12, color: Tv.gold)),
            ),
            if (mine != null)
              FilledButton.icon(
                key: const ValueKey('lobby-mine'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42)),
                onPressed: () => joinLobby(context, mine),
                icon: const Icon(Icons.meeting_room),
                label: Text('RETOURNER DANS MON SALON',
                    style: Tv.title(16, color: Colors.black)),
              )
            else
              OutlinedButton.icon(
                key: const ValueKey('lobby-create'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42)),
                onPressed: () => createLobby(context),
                icon: const Icon(Icons.add_home),
                label: Text('CRÉER UN SALON', style: Tv.title(16)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'SALONS OUVERTS (${cards.where((l) => l.id != mine).length})',
                  style: Tv.label(11, color: Tv.text)),
            ),
            if (cards.every((l) => l.id == mine))
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                    'Aucun salon public ouvert pour l\'instant. Les salons '
                    'privés n\'apparaissent pas ici : on y entre sur '
                    'invitation.',
                    style: Tv.label(11)),
              ),
            for (final l in cards)
              if (l.id != mine)
                ListTile(
                  key: ValueKey('lobby-card-${l.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: PlayerAvatar(
                      name: l.host.name,
                      color: l.host.color,
                      size: 32,
                      id: l.host.key),
                  title: Text(
                      'SALON DE ${l.host.name.toUpperCase()}'
                      '${l.from != null ? ' · INVITATION' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(15,
                          color: l.from != null ? Tv.goldLight : Tv.text)),
                  subtitle: Text(
                      '${l.homes}/$kLobbyHomes maisons · ${l.players} joueur'
                      '${l.players > 1 ? 's' : ''}'
                      '${l.label.isEmpty ? '' : ' · ${l.label}'}',
                      style: Tv.label(11)),
                  trailing: TextButton(
                    onPressed: () => joinLobby(context, l.id),
                    child: const Text('REJOINDRE'),
                  ),
                ),
          ],
        );
      },
    );
  }
}
