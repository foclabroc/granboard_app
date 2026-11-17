import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../game/x01.dart';
import '../players.dart';
import '../server.dart';
import 'relay.dart';

/// Joueur vu en ligne (ou adversaire d'une partie).
class OnlinePlayer {
  final int id;
  final String name;
  final int colorIndex;
  final double? rating;
  final bool busy;

  /// Hors ligne (liste de tous les joueurs du serveur).
  final bool offline;

  /// Lien d'amitié avec moi : '' | sent (je lui ai demandé) | ask (il me
  /// demande) | ok.
  final String friend;

  /// Ne veut pas être dérangé (pas de défi).
  final bool dnd;

  /// Dernière fois vu en ligne.
  final DateTime? seen;

  /// Phrase et titre de son profil.
  final String motto, title;

  /// Il veut jouer avec moi / je lui ai dit que je voulais jouer.
  final bool want, wanted;

  /// Mon bilan contre lui (amis) : victoires, défaites.
  final int wins, losses;

  /// Ami en partie en ligne : on peut la regarder.
  final bool watchable;
  const OnlinePlayer(
      {required this.id,
      required this.name,
      this.colorIndex = 0,
      this.rating,
      this.busy = false,
      this.offline = false,
      this.friend = '',
      this.dnd = false,
      this.seen,
      this.motto = '',
      this.title = '',
      this.want = false,
      this.wanted = false,
      this.wins = 0,
      this.losses = 0,
      this.watchable = false});

  factory OnlinePlayer.fromJson(Map j) => OnlinePlayer(
        id: (j['id'] as num).toInt(),
        name: '${j['pseudo'] ?? '?'}',
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        busy: j['busy'] == true || j['state'] == 'busy',
        offline: j['state'] == 'off',
        friend: '${j['friend'] ?? ''}',
        dnd: j['dnd'] == true,
        seen: DateTime.tryParse('${j['seen'] ?? ''}')?.toLocal(),
        motto: '${j['motto'] ?? ''}',
        title: '${j['title'] ?? ''}',
        want: j['want'] == true,
        wanted: j['wanted'] == true,
        wins: (j['w'] as num?)?.toInt() ?? 0,
        losses: (j['l'] as num?)?.toInt() ?? 0,
        watchable: j['room'] == true,
      );

  bool get isFriend => friend == 'ok';
  bool get blocked => friend == 'blocked';

  /// Peut être défié tout de suite.
  bool get free => !offline && !busy && !dnd && !blocked;

  String get key => '$id';
  Color get color => kPlayerColors[colorIndex % kPlayerColors.length];
}

/// Rendez-vous pour jouer avec [other].
class OnlineDate {
  final int id;
  final OnlinePlayer other;
  final DateTime at;

  /// Accepté ; sinon en attente de la réponse de celui qui l'a reçu.
  final bool ok;

  /// C'est moi qui l'ai proposé.
  final bool mine;
  const OnlineDate(this.id, this.other, this.at, this.ok, this.mine);
}

/// « Il y a 5 min », « hier », « le 12/11 » (dernière connexion).
String agoText(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 2) return 'à l\'instant';
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'il y a ${d.inHours} h';
  if (d.inDays < 2) return 'hier';
  if (d.inDays < 7) return 'il y a ${d.inDays} jours';
  String two(int n) => n.toString().padLeft(2, '0');
  return 'le ${two(t.day)}/${two(t.month)}';
}

/// Défi reçu.
class OnlineInvite {
  final int id;
  final OnlinePlayer from;
  final Map<String, dynamic> game;
  const OnlineInvite(this.id, this.from, this.game);
}

/// Mon dernier défi envoyé : pending, accepted (+ [room]), declined,
/// cancelled, expired.
class SentInvite {
  final int id;
  final int to;
  final String status;
  final int? room;
  const SentInvite(this.id, this.to, this.status, this.room);
}

/// Salon (liste des salons publics, invitation reçue).
class LobbyCard {
  final int id;
  final OnlinePlayer host;
  final bool public;
  final String label;

  /// Maisons (cibles) et joueurs déjà dans le salon.
  final int homes, players;

  /// Qui m'a invité (invitation reçue).
  final OnlinePlayer? from;
  const LobbyCard(this.id, this.host,
      {this.public = false,
      this.label = '',
      this.homes = 1,
      this.players = 1,
      this.from});

  factory LobbyCard.fromJson(Map j) => LobbyCard(
        (j['id'] as num).toInt(),
        OnlinePlayer.fromJson(j['host'] as Map),
        public: j['public'] == true,
        label: '${j['label'] ?? ''}',
        homes: (j['homes'] as num?)?.toInt() ?? 1,
        players: (j['players'] as num?)?.toInt() ?? 1,
        from: j['from'] is Map ? OnlinePlayer.fromJson(j['from'] as Map) : null,
      );
}

/// Maisons d'un salon : 4 au plus, chacune avec 4 joueurs au plus.
const kLobbyHomes = 4;
const kLobbyHomePlayers = 4;

/// Présence en ligne et défis du profil principal du téléphone.
/// Tourne tant que l'appli est ouverte (au premier plan).
class OnlineService extends ChangeNotifier with WidgetsBindingObserver {
  OnlineService._() : _account = null;
  static final instance = OnlineService._();

  /// Service d'un compte donné (tests : deux téléphones dans le même
  /// programme).
  @visibleForTesting
  OnlineService.forAccount(PlayerProfile account) : _account = account;
  final PlayerProfile? _account;

  /// Rythme des appels de présence (plus rapide sur l'écran « En ligne »).
  static const _slow = Duration(seconds: 10);
  static const _fast = Duration(seconds: 4);

  List<OnlinePlayer> players = const [];

  /// Tous les joueurs du serveur, avec leur état et le lien d'amitié
  /// (relu tant que l'écran « En ligne » est ouvert).
  List<OnlinePlayer> people = const [];

  /// Demandes d'ami reçues.
  List<OnlinePlayer> asks = const [];

  /// Joueurs qui veulent jouer avec moi (message laissé en mon absence).
  List<OnlinePlayer> wants = const [];

  /// Mes rendez-vous (proposés ou reçus).
  List<OnlineDate> dates = const [];

  /// Je ne veux pas être dérangé (pas de défi).
  bool dnd = false;

  /// Phrase et titre de mon profil.
  String motto = '', title = '';
  OnlineInvite? invite;
  SentInvite? sent;

  /// Partie en ligne interrompue qu'on peut reprendre.
  int? resumeRoom;

  /// Invitations reçues dans un salon, et mon salon ouvert.
  List<LobbyCard> lobbyInvites = const [];
  int? lobby;

  /// Salons publics ouverts (relus tant que l'écran « En ligne » est ouvert).
  List<LobbyCard> lobbies = const [];

  /// Dernier appel réussi (sinon [error] dit pourquoi).
  bool connected = false;
  String? error;

  /// Parties ouvertes sur ce téléphone (locales ou en ligne) : pendant une
  /// partie, on ne reçoit pas de défi.
  int inGame = 0;

  /// Écrans « En ligne » ouverts (liste rafraîchie plus souvent).
  int _watchers = 0;

  bool _started = false;
  bool _foreground = true;
  Timer? _timer;
  bool _pinging = false;
  VoidCallback? _unlisten;
  String? _topic;

  PlayerProfile? get me {
    final o = _account ?? PlayerStore.instance.owner;
    return o == null || o.expired ? null : o;
  }

  /// À appeler une fois au démarrage (mode téléphone).
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    PlayerStore.instance.addListener(_accountsChanged);
    _schedule();
    ping();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    PlayerStore.instance.removeListener(_accountsChanged);
    _timer?.cancel();
    _unlisten?.call();
    _unlisten = null;
    _topic = null;
  }

  int? _lastMe;
  void _accountsChanged() {
    if (me?.id != _lastMe) ping();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;
    if (fg) {
      _schedule();
      ping();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      final m = me;
      // En partie en ligne, la salle garde la présence ; sinon on disparaît
      if (m != null && inGame == 0) {
        GbServer.rpc('gb_on_bye', {'p_token': m.token}).catchError((_) {});
      }
    }
  }

  /// L'écran « En ligne » est ouvert : liste rafraîchie plus souvent.
  void watch() {
    _watchers++;
    _schedule();
    ping();
  }

  void unwatch() {
    if (_watchers > 0) _watchers--;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_started || !_foreground) return;
    _timer = Timer.periodic(_watchers > 0 ? _fast : _slow, (_) => ping());
  }

  /// Signale ma présence et relit joueurs en ligne et défis.
  Future<void> ping() async {
    final m = me;
    _lastMe = m?.id;
    if (m == null) {
      if (players.isNotEmpty || invite != null || connected) {
        players = const [];
        people = const [];
        asks = const [];
        wants = const [];
        dates = const [];
        invite = null;
        sent = null;
        lobbyInvites = const [];
        lobby = null;
        connected = false;
        notifyListeners();
      }
      return;
    }
    if (_pinging) return;
    _pinging = true;
    try {
      final r = Map<String, dynamic>.from(await GbServer.rpc(
          'gb_on_ping', {'p_token': m.token, 'p_busy': inGame > 0}) as Map);
      connected = true;
      error = null;
      players = [
        for (final p in (r['online'] as List? ?? const []))
          OnlinePlayer.fromJson(p as Map)
      ];
      for (final p in players) {
        PlayerStore.instance.remoteColors[p.key] = p.color;
      }
      final i = r['invite'];
      invite = i is Map && inGame == 0
          ? OnlineInvite(
              (i['id'] as num).toInt(),
              OnlinePlayer.fromJson(i['from'] as Map),
              Map<String, dynamic>.from(i['game'] as Map))
          : null;
      final s = r['sent'];
      sent = s is Map
          ? SentInvite((s['id'] as num).toInt(), (s['to'] as num).toInt(),
              '${s['status']}', (s['room'] as num?)?.toInt())
          : null;
      resumeRoom = (r['room'] as num?)?.toInt();
      lobbyInvites = inGame > 0
          ? const []
          : [
              for (final l in (r['lobby_invites'] as List? ?? const []))
                LobbyCard.fromJson(l as Map)
            ];
      lobby = (r['lobby'] as num?)?.toInt();
      asks = [
        for (final p in (r['asks'] as List? ?? const []))
          OnlinePlayer.fromJson(p as Map)
      ];
      wants = [
        for (final p in (r['wants'] as List? ?? const []))
          OnlinePlayer.fromJson(p as Map)
      ];
      dates = [
        for (final d in (r['dates'] as List? ?? const []))
          if (d is Map && DateTime.tryParse('${d['at']}') != null)
            OnlineDate(
                (d['id'] as num).toInt(),
                OnlinePlayer.fromJson(d['with'] as Map),
                DateTime.parse('${d['at']}').toLocal(),
                d['ok'] == true,
                d['mine'] == true)
      ];
      dnd = r['dnd'] == true;
      motto = '${r['motto'] ?? ''}';
      title = '${r['title'] ?? ''}';
      final topic = r['topic'] as String?;
      if (topic != null && topic != _topic) {
        _unlisten?.call();
        _topic = topic;
        _unlisten = Relay.instance.listen(topic, ping);
      }
    } on ApiError catch (e) {
      connected = false;
      error = e.message;
      if (e.code == 'session') PlayerStore.instance.sync();
    } catch (_) {
      connected = false;
    } finally {
      _pinging = false;
    }
    notifyListeners();
    if (_watchers > 0 && connected) await loadPeople();
  }

  /// Relit tous les joueurs du serveur (et les salons publics).
  Future<void> loadPeople() async {
    final m = me;
    if (m == null) return;
    loadLobbies();
    try {
      final r = await GbServer.rpc('gb_on_people', {'p_token': m.token});
      people = [for (final p in r as List) OnlinePlayer.fromJson(p as Map)];
      for (final p in people) {
        PlayerStore.instance.remoteColors[p.key] = p.color;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Demande [p] en ami (ou accepte s'il m'avait demandé). Lève ApiError.
  Future<void> askFriend(OnlinePlayer p) async {
    await GbServer.rpc('gb_friend_ask', {'p_token': me!.token, 'p_to': p.id});
    await _friendsChanged();
  }

  /// Répond à la demande d'ami de [p].
  Future<void> answerFriend(OnlinePlayer p, bool accept) async {
    await GbServer.rpc('gb_friend_answer',
        {'p_token': me!.token, 'p_from': p.id, 'p_accept': accept});
    await _friendsChanged();
  }

  /// Retire [p] de mes amis, ou annule ma demande.
  Future<void> removeFriend(OnlinePlayer p) async {
    await GbServer.rpc(
        'gb_friend_remove', {'p_token': me!.token, 'p_other': p.id});
    await _friendsChanged();
  }

  /// Laisse (ou retire) « je veux jouer avec toi » à [p].
  Future<void> want(OnlinePlayer p, [bool on = true]) async {
    await GbServer.rpc(
        'gb_on_want', {'p_token': me!.token, 'p_to': p.id, 'p_on': on});
    await _friendsChanged();
  }

  /// Bloque (ou débloque) [p].
  Future<void> block(OnlinePlayer p, [bool on = true]) async {
    await GbServer.rpc(
        'gb_block', {'p_token': me!.token, 'p_other': p.id, 'p_on': on});
    await _friendsChanged();
  }

  /// « Ne pas déranger » : visible en ligne, sans recevoir de défi.
  Future<void> setDnd(bool on) async {
    await GbServer.rpc('gb_on_dnd', {'p_token': me!.token, 'p_on': on});
    dnd = on;
    notifyListeners();
  }

  /// Phrase de mon profil (60 caractères au plus).
  Future<void> setMotto(String text) async {
    final r = await GbServer.rpc(
        'gb_set_motto', {'p_token': me!.token, 'p_motto': text});
    motto = '${r ?? ''}';
    notifyListeners();
  }

  /// Propose un rendez-vous à [p].
  Future<void> proposeDate(OnlinePlayer p, DateTime at) async {
    await GbServer.rpc('gb_date_set', {
      'p_token': me!.token,
      'p_to': p.id,
      'p_at': at.toUtc().toIso8601String()
    });
    await ping();
  }

  /// Accepte un rendez-vous reçu, ou le retire.
  Future<void> answerDate(int id, bool accept) async {
    await GbServer.rpc('gb_date_answer',
        {'p_token': me!.token, 'p_id': id, 'p_accept': accept});
    await ping();
  }

  /// Ids de mes amis (classements).
  Future<Set<int>> friendIds() async {
    final m = me;
    if (m == null) return const {};
    final r = await GbServer.rpc('gb_friend_ids', {'p_token': m.token});
    return {for (final x in r as List) (x as num).toInt()};
  }

  /// Partie en ligne de l'ami [playerId] : son JSON, ou null si finie.
  Future<Map<String, dynamic>?> watchGame(int playerId) async {
    try {
      final r = await GbServer.rpc(
          'gb_on_watch', {'p_token': me!.token, 'p_player': playerId});
      return Map<String, dynamic>.from((r as Map)['game'] as Map);
    } on ApiError catch (e) {
      if (e.code == 'on_gone') return null;
      rethrow;
    }
  }

  Future<void> _friendsChanged() async {
    await loadPeople();
    await ping();
  }

  /// Défie [p] avec la partie [game] (lève ApiError) ; renvoie l'id du défi.
  Future<int> challenge(OnlinePlayer p, Map<String, dynamic> game) async {
    final r = await GbServer.rpc(
        'gb_on_invite', {'p_token': me!.token, 'p_to': p.id, 'p_game': game});
    final id = ((r as Map)['id'] as num).toInt();
    sent = SentInvite(id, p.id, 'pending', null);
    notifyListeners();
    return id;
  }

  /// Lance mon match de tournoi [round]/[slot] : défi à [p] créé par le
  /// serveur avec la partie du tournoi (lève ApiError) ; renvoie l'id.
  Future<int> challengeTournament(
      int tournament, int round, int slot, OnlinePlayer p) async {
    final r = await GbServer.rpc('gb_tn_challenge', {
      'p_token': me!.token,
      'p_id': tournament,
      'p_round': round,
      'p_slot': slot,
    });
    final id = ((r as Map)['id'] as num).toInt();
    sent = SentInvite(id, p.id, 'pending', null);
    notifyListeners();
    return id;
  }

  Future<void> cancel(int inviteId) async {
    final m = me;
    if (m == null) return;
    try {
      await GbServer.rpc(
          'gb_on_cancel', {'p_token': m.token, 'p_invite': inviteId});
    } on ApiError catch (_) {}
    if (sent?.id == inviteId) sent = null;
    notifyListeners();
  }

  /// Répond au défi reçu ; renvoie la salle si accepté (lève ApiError
  /// « on_gone » si le défi n'existe plus).
  /// En double, [game] = la partie complétée avec mon coéquipier
  /// ([completeDouble]).
  Future<int?> answer(int inviteId, bool accept,
      {Map<String, dynamic>? game}) async {
    final m = me;
    if (m == null) return null;
    if (invite?.id == inviteId) {
      invite = null;
      notifyListeners();
    }
    final r = await GbServer.rpc('gb_on_answer', {
      'p_token': m.token,
      'p_invite': inviteId,
      'p_accept': accept,
      if (game != null) 'p_game': game,
    });
    return r is Map ? (r['room'] as num?)?.toInt() : null;
  }

  /// Relit les salons publics ouverts.
  Future<void> loadLobbies() async {
    final m = me;
    if (m == null) return;
    try {
      final r = Map<String, dynamic>.from(
          await GbServer.rpc('gb_lb_list', {'p_token': m.token}) as Map);
      lobbies = [
        for (final l in (r['public'] as List? ?? const []))
          LobbyCard.fromJson(l as Map)
      ];
      lobby = (r['mine'] as num?)?.toInt();
      notifyListeners();
    } catch (_) {}
  }

  /// Joueurs de ma maison par défaut : mon profil.
  List<X01Player> get homePlayers {
    final m = me;
    return m == null ? const [] : [X01Player(id: m.key, name: m.name)];
  }

  /// Crée un salon (je quitte les autres) ; lève ApiError.
  Future<Lobby> createLobby(bool public, [List<X01Player>? players]) async {
    final r = await GbServer.rpc('gb_lb_create', {
      'p_token': me!.token,
      'p_public': public,
      'p_players': Lobby.playersJson(players ?? homePlayers),
    });
    final j = Map<String, dynamic>.from(r as Map);
    final l = Lobby((j['id'] as num).toInt(), me!)..apply(j);
    lobby = l.id;
    notifyListeners();
    return l;
  }

  /// Rejoint le salon [id] (public ou invité) ; lève ApiError.
  Future<Lobby> joinLobby(int id, [List<X01Player>? players]) async {
    final r = await GbServer.rpc('gb_lb_join', {
      'p_token': me!.token,
      'p_id': id,
      'p_players': Lobby.playersJson(players ?? homePlayers),
    });
    lobbyInvites = [
      for (final l in lobbyInvites)
        if (l.id != id) l
    ];
    lobby = id;
    notifyListeners();
    return Lobby(id, me!)..apply(Map<String, dynamic>.from(r as Map));
  }

  /// Ouvre mon salon [id] (lève ApiError « lb_gone » s'il n'existe plus).
  Future<Lobby> openLobby(int id) async {
    final r =
        await GbServer.rpc('gb_lb_get', {'p_token': me!.token, 'p_id': id});
    return Lobby(id, me!)..apply(Map<String, dynamic>.from(r as Map));
  }

  /// Refuse l'invitation au salon [id].
  Future<void> declineLobby(int id) async {
    lobbyInvites = [
      for (final l in lobbyInvites)
        if (l.id != id) l
    ];
    notifyListeners();
    final m = me;
    if (m == null) return;
    try {
      await GbServer.rpc('gb_lb_decline', {'p_token': m.token, 'p_id': id});
    } catch (_) {}
  }

  /// Ouvre la salle [id] (lève ApiError si elle n'existe plus).
  Future<OnlineRoom> openRoom(int id) async {
    final room = OnlineRoom(id, me!);
    await room.start();
    return room;
  }
}

/// Maison d'un salon : le compte qui la tient et ses joueurs.
class LobbyMember {
  final OnlinePlayer player;
  final List<X01Player> players;

  /// Secondes depuis son dernier signe de vie.
  final int age;
  const LobbyMember(this.player, this.players, this.age);
}

/// Salon ouvert : 2 à 4 maisons (chacune sur sa cible, avec ses joueurs),
/// l'hôte choisit le jeu et lance. Relu sur notification du relais et
/// toutes les 4 s (ce qui dit aussi au serveur que je suis là).
class Lobby extends ChangeNotifier {
  Lobby(this.id, this.account);

  /// Relecture régulière (fausse en test : appels à la main).
  static bool pollEnabled = true;

  final int id;
  final PlayerProfile account;

  int hostId = 0;
  bool public = false;

  /// Jeu choisi par l'hôte : {kind, settings, label, order} (sans joueurs).
  Map<String, dynamic>? game;
  String status = 'open';

  /// Salle de la partie lancée.
  int? room;
  List<LobbyMember> members = const [];

  /// Joueurs invités qui n'ont pas encore rejoint (status pending/declined).
  List<(OnlinePlayer, String)> invited = const [];

  /// Le salon n'existe plus (ou j'en ai été retiré).
  bool gone = false;
  String? error;

  bool get isHost => hostId == account.id;
  bool get started => status == 'started';
  OnlinePlayer? get host {
    for (final m in members) {
      if (m.player.id == hostId) return m.player;
    }
    return null;
  }

  LobbyMember? get mine {
    for (final m in members) {
      if (m.player.id == account.id) return m;
    }
    return null;
  }

  /// Tous les joueurs du salon, maison par maison.
  List<X01Player> get allPlayers => [
        for (final m in members) ...m.players,
      ];

  bool get full => members.length >= kLobbyHomes;

  static List<Map<String, dynamic>> playersJson(List<X01Player> ps) => [
        for (final p in ps) {'id': p.id, 'name': p.name}
      ];

  void apply(Map<String, dynamic> j) {
    hostId = (j['host'] as num?)?.toInt() ?? hostId;
    public = j['public'] == true;
    game =
        j['game'] is Map ? Map<String, dynamic>.from(j['game'] as Map) : null;
    status = '${j['status'] ?? status}';
    room = (j['room'] as num?)?.toInt();
    members = [
      for (final m in (j['members'] as List? ?? const []))
        LobbyMember(
          OnlinePlayer.fromJson(m as Map),
          [
            for (final p in (m['players'] as List? ?? const []))
              X01Player(id: '${(p as Map)['id']}', name: '${p['name']}')
          ],
          (m['age'] as num?)?.toInt() ?? 0,
        )
    ];
    for (final m in members) {
      PlayerStore.instance.remoteColors[m.player.key] = m.player.color;
    }
    invited = [
      for (final i in (j['invited'] as List? ?? const []))
        (OnlinePlayer.fromJson(i as Map), '${i['status'] ?? 'pending'}')
    ];
    final topic = j['topic'] as String?;
    if (topic != null && topic != _topic && !_closed) {
      _unlisten?.call();
      _topic = topic;
      _unlisten = Relay.instance.listen(topic, fetch);
    }
  }

  Timer? _poll;
  VoidCallback? _unlisten;
  String? _topic;
  bool _closed = false;
  bool _fetching = false;

  /// Lance la relecture régulière.
  void listen() {
    if (_closed) return;
    _poll?.cancel();
    if (pollEnabled) {
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => fetch());
    }
  }

  Future<void> fetch() async {
    if (_closed || _fetching) return;
    _fetching = true;
    try {
      _set(await _rpc('gb_lb_get', {}));
    } on ApiError catch (e) {
      if (e.code == 'lb_gone') {
        gone = true;
      } else {
        error = e.message;
      }
      notifyListeners();
    } catch (_) {
    } finally {
      _fetching = false;
    }
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> args) =>
      GbServer.rpc(fn, {'p_token': account.token, 'p_id': id, ...args});

  void _set(dynamic r) {
    if (_closed || r is! Map) return;
    error = null;
    apply(Map<String, dynamic>.from(r));
    notifyListeners();
  }

  /// Joueurs de ma maison (1 à 4) ; lève ApiError.
  Future<void> setPlayers(List<X01Player> players) async =>
      _set(await _rpc('gb_lb_players', {'p_players': playersJson(players)}));

  /// Jeu choisi (JSON d'une partie, ses joueurs ne sont pas gardés) et
  /// ouverture : hôte seulement ; lève ApiError.
  Future<void> setGame(Map<String, dynamic>? game, {bool? public}) async =>
      _set(await _rpc('gb_lb_set', {'p_game': game, 'p_public': public}));

  Future<void> invite(OnlinePlayer p) async =>
      _set(await _rpc('gb_lb_invite', {'p_to': p.id}));

  Future<void> kick(OnlinePlayer p) async =>
      _set(await _rpc('gb_lb_kick', {'p_player': p.id}));

  /// Partie complète à lancer : le jeu choisi avec les joueurs de toutes
  /// les maisons, en alternance (1er joueur de chaque maison, puis le 2e…),
  /// maisons tirées au hasard si l'hôte l'a demandé.
  Map<String, dynamic>? buildGame([Random? rnd]) {
    final g = game;
    if (g == null) return null;
    final homes = [for (final m in members) m.players];
    if (g['order'] == 'random') homes.shuffle(rnd ?? Random());
    final n = homes.fold<int>(0, (a, h) => max(a, h.length));
    final order = [
      for (var i = 0; i < n; i++)
        for (final h in homes)
          if (i < h.length) h[i]
    ];
    return {
      ...g,
      'players': [
        for (var i = 0; i < order.length; i++)
          X01Player(id: order[i].id, name: order[i].name, team: i).toJson()
      ],
      'actions': const <String>[],
    };
  }

  /// L'hôte lance la partie ; renvoie la salle (lève ApiError).
  Future<int> start(Map<String, dynamic> game) async {
    final r = await _rpc('gb_lb_start', {'p_game': game});
    room = ((r as Map)['room'] as num).toInt();
    status = 'started';
    notifyListeners();
    return room!;
  }

  /// Retour au salon après la partie (il se rouvre pour tout le monde).
  Future<void> back() async {
    try {
      _set(await _rpc('gb_lb_back', {}));
    } on ApiError catch (e) {
      if (e.code == 'lb_gone') {
        gone = true;
        notifyListeners();
      }
    }
  }

  /// Quitte le salon (l'hôte passe la main) et arrête la relecture.
  Future<void> leave() async {
    close();
    try {
      await _rpc('gb_lb_leave', {});
    } catch (_) {}
    final s = OnlineService.instance;
    if (s.lobby == id) {
      s.lobby = null;
      s.ping();
    }
  }

  void close() {
    _closed = true;
    _poll?.cancel();
    _unlisten?.call();
    _unlisten = null;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

/// Maison d'une partie de salon (h1 = hôte).
class RoomHome {
  final String home;
  final OnlinePlayer player;
  final int age;
  final bool left;
  const RoomHome(this.home, this.player, this.age, this.left);
}

/// Salle d'une partie en ligne : la partie est sur le serveur, chaque
/// téléphone envoie son journal d'actions après avoir joué et relit celui de
/// l'autre. Transporte aussi les messages de mise en relation de la vidéo.
class OnlineRoom extends ChangeNotifier {
  OnlineRoom(this.id, this.account);

  /// Vidéo activée (faux en test : pas de caméra).
  static bool videoEnabled = true;

  final int id;
  final PlayerProfile account;

  /// Identifiant de mon joueur dans la partie.
  String get myId => account.key;

  /// Le joueur [id] lance chez moi ? En double, la partie dit qui joue dans
  /// quelle maison (« home » : a = qui a défié, b = l'autre). Salon : la
  /// maison qui a quitté la partie est remplacée par la 1re maison encore
  /// là (ses joueurs passent leur tour, voir [goneHome]).
  bool mine(String id) {
    final home = game['home'];
    if (home is Map) {
      final h = home[id];
      if (h == side) return true;
      return h != null && goneHome('$h') && side == firstPresent;
    }
    return id == myId;
  }

  /// Maisons d'une partie de salon (vide en 1 contre 1).
  List<RoomHome> homes = const [];
  bool get isSalon => homes.isNotEmpty;

  /// Salon d'où vient la partie.
  int? get salon => (game['salon'] as num?)?.toInt();

  /// La maison [h] a quitté la partie.
  bool goneHome(String h) => homes.any((x) => x.home == h && x.left);

  /// Le joueur [id] est chez une maison partie (il passe son tour).
  bool absent(String id) {
    final home = game['home'];
    return isSalon &&
        home is Map &&
        home[id] != null &&
        goneHome('${home[id]}');
  }

  /// 1re maison encore dans la partie.
  String? get firstPresent {
    for (final h in homes) {
      if (!h.left) return h.home;
    }
    return null;
  }

  /// Autres maisons encore là (vidéo).
  List<RoomHome> get others => [
        for (final h in homes)
          if (h.home != side && !h.left) h
      ];

  /// « a » = celui qui a défié (il lance l'appel vidéo).
  String side = 'a';
  OnlinePlayer? peer;

  /// Partie telle que le serveur la connaît (réglages, joueurs, actions).
  Map<String, dynamic> game = const {};
  List<String> get actions =>
      [for (final a in (game['actions'] as List? ?? const [])) '$a'];

  int seq = 0;

  /// Augmente chaque fois que [game] est remplacé par celui du serveur.
  int gameVersion = 0;

  /// Secondes depuis le dernier signe de vie de l'adversaire.
  int peerAge = 0;

  /// Un joueur a quitté la partie.
  bool left = false;
  String? error;
  List<dynamic> ice = const [];

  final _signals = StreamController<Map<String, dynamic>>.broadcast();

  /// Messages vidéo de l'adversaire.
  Stream<Map<String, dynamic>> get signals => _signals.stream;

  int _sig = 0;
  Timer? _poll;
  VoidCallback? _unlisten;
  String? _topic;
  bool _fetching = false;
  bool _again = false;
  bool _closed = false;
  bool _leaving = false;
  List<String>? _pendingPush;
  bool _pushing = false;

  /// Vrai quand le dernier envoi a été refusé (l'autre a joué entre-temps) :
  /// la partie affichée doit être reconstruite depuis [game].
  bool conflict = false;

  Future<void> start() async {
    await fetch(rethrowErrors: true);
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      // Relecture de secours : rapide sans relais, lente avec
      final live = _topic != null && Relay.instance.isLive(_topic!);
      if (!live || t.tick % 4 == 0) fetch();
    });
  }

  /// Relit la salle (partie si elle a changé, messages vidéo, présence).
  Future<void> fetch({bool rethrowErrors = false}) async {
    if (_closed) return;
    if (_fetching) {
      _again = true;
      return;
    }
    _fetching = true;
    try {
      final since = seq;
      final r = Map<String, dynamic>.from(await GbServer.rpc('gb_on_get', {
        'p_token': account.token,
        'p_room': id,
        'p_since': since,
        'p_sig': _sig
      }) as Map);
      if (_closed) return;
      error = null;
      side = '${r['side'] ?? side}';
      if (r['peer'] is Map) {
        peer = OnlinePlayer.fromJson(r['peer'] as Map);
        PlayerStore.instance.remoteColors[peer!.key] = peer!.color;
      }
      peerAge = (r['peer_age'] as num?)?.toInt() ?? 0;
      left = r['left'] == true;
      homes = [
        for (final h in (r['homes'] as List? ?? const []))
          if (h is Map && h['player'] is Map)
            RoomHome('${h['home']}', OnlinePlayer.fromJson(h['player'] as Map),
                (h['age'] as num?)?.toInt() ?? 0, h['left'] == true)
      ];
      for (final h in homes) {
        PlayerStore.instance.remoteColors[h.player.key] = h.player.color;
      }
      ice = r['ice'] as List? ?? const [];
      final topic = r['topic'] as String?;
      if (topic != null && topic != _topic) {
        _unlisten?.call();
        _topic = topic;
        _unlisten = Relay.instance.listen(topic, fetch);
      }
      final s = (r['seq'] as num?)?.toInt() ?? seq;
      // Pendant un envoi, c'est ce téléphone qui a la partie la plus récente
      if (r['game'] is Map && s > seq && !_pushing && _pendingPush == null) {
        seq = s;
        game = Map<String, dynamic>.from(r['game'] as Map);
        gameVersion++;
      }
      for (final m in (r['signals'] as List? ?? const [])) {
        final sid = ((m as Map)['id'] as num).toInt();
        if (sid <= _sig) continue;
        _sig = sid;
        if (m['data'] is Map) {
          // Salon : maison qui envoie (donnée par le serveur)
          _signals.add({
            ...Map<String, dynamic>.from(m['data'] as Map),
            if (m['from'] != null) '_from': '${m['from']}',
          });
        }
      }
      notifyListeners();
    } on ApiError catch (e) {
      if (rethrowErrors) rethrow;
      if (e.code == 'on_room') {
        left = true;
      } else {
        error = e.message;
      }
      notifyListeners();
    } finally {
      _fetching = false;
      if (_again && !_closed) {
        _again = false;
        fetch();
      }
    }
  }

  /// Envoie mon journal d'actions (le dernier envoi demandé gagne).
  void push(List<String> log) {
    if (_closed) return;
    _pendingPush = List.of(log);
    if (!_pushing) _flush();
  }

  Future<void> _flush() async {
    _pushing = true;
    try {
      while (_pendingPush != null && !_closed) {
        final log = _pendingPush!;
        _pendingPush = null;
        final next = {...game, 'actions': log};
        try {
          final r = Map<String, dynamic>.from(await GbServer.rpc('gb_on_push', {
            'p_token': account.token,
            'p_room': id,
            'p_seq': seq,
            'p_game': next
          }) as Map);
          seq = (r['seq'] as num).toInt();
          game = next;
          if (error != null) {
            error = null;
            notifyListeners();
          }
        } on ApiError catch (e) {
          if (e.code == 'on_conflict' ||
              e.code == 'on_game' ||
              e.code == 'on_room') {
            // L'autre a joué entre-temps (ou la salle est fermée) : on
            // repart de la partie du serveur
            _pendingPush = null;
            conflict = true;
            _pushing = false;
            seq = 0;
            await fetch();
            return;
          }
          // Hors ligne : on retente avec le journal le plus récent
          error = e.message;
          _pendingPush ??= log;
          notifyListeners();
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      _pushing = false;
    }
  }

  Future<void> signal(Map<String, dynamic> data) async {
    if (_closed) return;
    try {
      await GbServer.rpc('gb_on_signal',
          {'p_token': account.token, 'p_room': id, 'p_data': data});
    } on ApiError catch (_) {}
  }

  /// Quitte la partie (l'adversaire est prévenu) et ferme la salle.
  Future<void> leave() async {
    if (_closed || _leaving) return;
    _leaving = true;
    // Laisse partir le dernier envoi (la fléchette de la victoire…)
    final end = DateTime.now().add(const Duration(seconds: 5));
    while ((_pushing || _pendingPush != null) && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    close();
    try {
      await GbServer.rpc(
          'gb_on_leave', {'p_token': account.token, 'p_room': id});
    } on ApiError catch (_) {}
  }

  void close() {
    _closed = true;
    _poll?.cancel();
    _unlisten?.call();
    _unlisten = null;
    _signals.close();
  }
}

/// Défi en double reçu : la partie avec mon coéquipier [mate] ajouté à
/// mon équipe, joueurs en alternance (équipe qui commence, l'autre, …).
Map<String, dynamic> completeDouble(
    Map<String, dynamic> invite, String myId, X01Player mate) {
  final players = [
    for (final p in (invite['players'] as List))
      X01Player.fromJson(Map<String, dynamic>.from(p as Map))
  ];
  final myTeam = players.firstWhere((p) => p.id == myId).team;
  players.add(X01Player(id: mate.id, name: mate.name, team: myTeam));
  final first = players.first.team;
  final a = players.where((p) => p.team == first).toList();
  final b = players.where((p) => p.team != first).toList();
  final order = [
    for (var i = 0; i < a.length || i < b.length; i++) ...[
      if (i < a.length) a[i],
      if (i < b.length) b[i],
    ]
  ];
  final home = Map<String, dynamic>.from(invite['home'] as Map? ?? const {});
  home[mate.id] = 'b';
  return {
    ...invite,
    'players': [for (final p in order) p.toJson()],
    'home': home,
  };
}
