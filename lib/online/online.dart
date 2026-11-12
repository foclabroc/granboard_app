import 'dart:async';

import 'package:flutter/widgets.dart';

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
  const OnlinePlayer(
      {required this.id,
      required this.name,
      this.colorIndex = 0,
      this.rating,
      this.busy = false});

  factory OnlinePlayer.fromJson(Map j) => OnlinePlayer(
        id: (j['id'] as num).toInt(),
        name: '${j['pseudo'] ?? '?'}',
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        busy: j['busy'] == true,
      );

  String get key => '$id';
  Color get color => kPlayerColors[colorIndex % kPlayerColors.length];
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
  OnlineInvite? invite;
  SentInvite? sent;

  /// Partie en ligne interrompue qu'on peut reprendre.
  int? resumeRoom;

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
        invite = null;
        sent = null;
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
  Future<int?> answer(int inviteId, bool accept) async {
    final m = me;
    if (m == null) return null;
    if (invite?.id == inviteId) {
      invite = null;
      notifyListeners();
    }
    final r = await GbServer.rpc('gb_on_answer',
        {'p_token': m.token, 'p_invite': inviteId, 'p_accept': accept});
    return r is Map ? (r['room'] as num?)?.toInt() : null;
  }

  /// Ouvre la salle [id] (lève ApiError si elle n'existe plus).
  Future<OnlineRoom> openRoom(int id) async {
    final room = OnlineRoom(id, me!);
    await room.start();
    return room;
  }
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
          _signals.add(Map<String, dynamic>.from(m['data'] as Map));
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
