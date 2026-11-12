import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio.dart';
import '../board_service.dart';
import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import '../granboard.dart';
import '../media.dart';
import '../online/online.dart';
import '../online/video.dart';
import '../players.dart';
import '../tv_link.dart';
import 'cricket_view.dart';
import 'dartboard.dart';
import 'match_view.dart';
import 'practice_view.dart';
import 'game_fx.dart';
import 'results_page.dart';
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'sound_settings.dart';
import 'theme.dart';
import 'widgets.dart';

/// Partie en cours (01 / Freeze avec [settings] + [players], ou [game] déjà
/// prêt : Cricket…).
class GamePage extends StatefulWidget {
  final X01Settings? settings;
  final List<X01Player>? players;
  final DartsGame? game;

  /// Partie en ligne : salle partagée avec l'adversaire ([game] vient d'elle).
  final OnlineRoom? online;
  const GamePage(
      {super.key, this.settings, this.players, this.game, this.online})
      : assert(game != null || (settings != null && players != null));

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late DartsGame game =
      widget.game ?? X01Game(widget.settings!, widget.players!);
  OnlineRoom? get _room => widget.online;
  VideoCall? _video;
  int _roomVersion = 0;
  late final StreamSubscription<BoardEvent> _sub;
  final _splash = GlobalKey<GameSplashState>();
  late final _fx = GameFx(_splash);
  final audio = AudioService.instance;

  @override
  void initState() {
    super.initState();
    _sub = BoardService.instance.events.listen(_onEvent);
    WakelockPlus.enable().catchError((_) {});
    audio.stopMusic();
    MediaStore.instance.ensure(game.players.map((p) => p.id));
    _fx.start(game);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushTv());
    OnlineService.instance.inGame++;
    final room = _room;
    if (room != null) {
      _roomVersion = room.gameVersion;
      room.addListener(_onRoom);
      if (OnlineRoom.videoEnabled) _video = VideoCall(room)..start();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    WakelockPlus.disable().catchError((_) {});
    final online = OnlineService.instance;
    if (online.inGame > 0) online.inGame--;
    final room = _room;
    if (room != null) {
      room.removeListener(_onRoom);
      _video?.close();
      room.leave().whenComplete(online.ping);
    }
    super.dispose();
  }

  // ─── Partie en ligne ───

  /// C'est à ce téléphone de jouer (toujours vrai hors ligne).
  bool get _canAct {
    final room = _room;
    if (room == null) return true;
    final g = game;
    if (g is MatchGame && g.betweenLegs) return true;
    return g.currentPlayer.id == room.myId;
  }

  DateTime _lastHint = DateTime(2000);

  void _notMyTurn() {
    final now = DateTime.now();
    if (now.difference(_lastHint) < const Duration(seconds: 3)) return;
    _lastHint = now;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('C\'est au tour de ${game.currentPlayer.name}')));
  }

  /// Après une action : envoi à l'adversaire et à la TV.
  void _sync() {
    _room?.push(game.actionLog);
    _pushTv();
  }

  /// La salle a changé : rejoue les actions de l'adversaire (effets pour la
  /// dernière seulement), ou repart de la partie du serveur.
  void _onRoom() {
    final room = _room!;
    if (!mounted) return;
    if (room.gameVersion == _roomVersion) {
      setState(() {}); // présence, connexion
      return;
    }
    _roomVersion = room.gameVersion;
    final actions = room.actions;
    final old = game.actionLog;
    final extends_ = !room.conflict &&
        actions.length >= old.length &&
        List.generate(old.length, (i) => old[i] == actions[i]).every((x) => x);
    room.conflict = false;
    setState(() {
      if (!extends_) {
        game = gameFromJson(room.game); // annulation ou conflit : sans effet
        return;
      }
      for (var i = old.length; i < actions.length; i++) {
        final a = actions[i];
        if (!game.applyLogEntry(a) || i != actions.length - 1) continue;
        _fx.afterAction(game, a);
      }
    });
    _pushTv();
  }

  void _onEvent(BoardEvent e) {
    switch (e) {
      case HitEvent(:final hit):
        _dart(hit);
      case ButtonEvent():
        _next();
      case MissEvent():
        _dart(null, outerRing: true);
      case UnknownEvent(:final raw):
        _unknown(raw);
    }
  }

  bool _unknownShown = false;

  /// Zone non reconnue : la cible n'est sans doute pas calibrée.
  void _unknown(String raw) {
    if (_unknownShown) return;
    _unknownShown = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text('Zone inconnue ("$raw"). Si ta cible n\'est pas une '
          'GranBoard Dash, calibre-la : Accueil › ⋮ › Calibrer cette cible.'),
    ));
  }

  void _dart(DartHit? hit, {bool outerRing = false}) {
    if (game.finished) return;
    if (!_canAct) return _notMyTurn();
    if (game.turnOver) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Manche terminée : retire tes fléchettes '
                'puis « Suivant »')));
      return;
    }
    setState(() => game.throwDart(hit));
    _fx.afterAnyDart(game, hit, outerRing: outerRing);
    _sync();
  }

  void _next() {
    if (game.finished) return;
    if (!_canAct) return _notMyTurn();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => game.next());
    _fx.afterAnyNext(game);
    _sync();
  }

  void _undo() {
    final room = _room;
    final log = game.actionLog;
    if (log.isEmpty) return;
    setState(() => game.undo());
    // En ligne, on n'annule que ses propres actions : après l'annulation,
    // ce doit être à moi de jouer
    if (room != null && game.currentPlayer.id != room.myId) {
      setState(() => game.applyLogEntry(log.last));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Tu ne peux annuler que tes propres actions')));
      return;
    }
    _sync();
  }

  void _pushTv() => TvLink.instance.pushGame(game);

  /// Choix de cible (entraînement).
  void _changeTarget(int n) {
    final g = game;
    if (g is! PracticeGame) return;
    if (!_canAct) return _notMyTurn();
    setState(() => g.changeTarget(n));
    audio.say('Nouvelle cible : ${n == 25 ? 'bull' : '$n'}');
    _sync();
  }

  Future<bool>? _saving;

  void _results() {
    // Envoi au serveur en arrière-plan : les résultats s'affichent tout de suite
    final g = game;
    _saving ??= switch (g) {
      X01Game g => PlayerStore.instance.recordX01(g),
      CricketGame g => PlayerStore.instance.recordCricket(g),
      MatchGame m => PlayerStore.instance.recordMatch(m),
      PracticeGame p => PlayerStore.instance.recordPractice(p),
      _ => Future.value(true),
    };
    TvLink.instance.pushGame(game, screen: 'results');
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => _room == null
                ? resultsPageFor(g, saving: _saving)
                : OnlineResultsPage(game: g, saving: _saving)));
  }

  Future<bool> _confirmQuit() async {
    if (game.finished) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abandonner la partie ?', style: Tv.title(22)),
        content: Text(_room == null
            ? 'Les statistiques ne seront pas enregistrées.'
            : 'Ton adversaire sera prévenu. Les statistiques ne seront pas '
                'enregistrées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuer')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abandonner')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final limit = game.roundLimit;
    final actionBar = _ActionBar(
      game: game,
      onUndo: _undo,
      onMiss: () => _dart(null),
      onNext: _next,
      onResults: _results,
      compact: game is CricketGame ||
          (game is MatchGame && (game as MatchGame).leg is CricketGame),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 46,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.title.toUpperCase(),
                  style: Tv.title(24, color: Tv.gold)),
              Text(game.rulesLabel.toUpperCase(), style: Tv.label(11)),
            ],
          ),
          actions: [
            if (_room != null && !game.finished)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TurnChip(mine: _canAct, name: game.currentPlayer.name),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Tv.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Tv.line),
              ),
              child: Column(
                children: [
                  Text('MANCHE', style: Tv.label(9)),
                  Text(
                    limit == null ? '${game.round}' : '${game.round}/$limit',
                    style: Tv.title(18),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sons',
              icon: const Icon(Icons.volume_up),
              onPressed: () => showSoundSettings(context),
            ),
          ],
        ),
        body: Column(
          children: [
            const BoardBanner(),
            if (_room != null)
              _OnlineBanner(
                  room: _room!,
                  finished: game.finished,
                  onQuit: () => Navigator.pop(context)),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: gameView(game, _splash,
                        actionBar: actionBar, onChangeTarget: _changeTarget),
                  ),
                  if (_video != null)
                    Positioned.fill(
                      child: VideoBubble(
                          call: _video!,
                          peerName: _room!.peer?.name ?? 'l\'adversaire'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En ligne : à qui de jouer.
class _TurnChip extends StatelessWidget {
  final bool mine;
  final String name;
  const _TurnChip({required this.mine, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = mine ? Tv.green : Tv.muted;
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c),
      ),
      child: Text(mine ? 'À TOI' : 'AU TOUR DE ${name.toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Tv.title(15, color: mine ? Tv.green : Tv.text)),
    );
  }
}

/// En ligne : bandeau fin si l'adversaire est parti, ne répond plus, ou si
/// le serveur est injoignable.
class _OnlineBanner extends StatelessWidget {
  final OnlineRoom room;
  final bool finished;
  final VoidCallback onQuit;
  const _OnlineBanner(
      {required this.room, required this.finished, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    final peer = room.peer?.name ?? 'Ton adversaire';
    String? text;
    var quit = false;
    if (room.left) {
      if (finished) return const SizedBox.shrink();
      text = '$peer a quitté la partie';
      quit = true;
    } else if (room.error != null) {
      text = 'Connexion au serveur perdue, nouvel essai…';
    } else if (room.peerAge >= 20) {
      text = '$peer ne répond plus (${room.peerAge} s)';
      quit = room.peerAge >= 60;
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      height: 34,
      color: Tv.red.withValues(alpha: 0.28),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.title(15)),
          ),
          if (quit) TextButton(onPressed: onQuit, child: const Text('QUITTER')),
        ],
      ),
    );
  }
}

/// Résultats d'une partie en ligne : ceux du jeu, sans « Rejouer » (la
/// revanche se lance depuis l'écran En ligne).
class OnlineResultsPage extends StatelessWidget {
  final DartsGame game;
  final Future<bool>? saving;
  const OnlineResultsPage({super.key, required this.game, this.saving});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: resultsPageFor(game, saving: saving, tv: true)),
        Positioned(
          right: 12,
          bottom: 10,
          child: SafeArea(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(150, 46)),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.public),
              label: Text('TERMINER', style: Tv.title(20, color: Colors.black)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Écran de partie selon le jeu (téléphone et TV).
Widget gameView(DartsGame game, GlobalKey<GameSplashState> splash,
        {Widget? actionBar, void Function(int)? onChangeTarget}) =>
    switch (game) {
      MatchGame m => gameView(m.leg, splash, actionBar: actionBar),
      PracticeGame g => PracticeLayout(
          game: g,
          splashKey: splash,
          actionBar: actionBar,
          onChangeTarget: onChangeTarget),
      CricketGame g =>
        CricketLayout(game: g, splashKey: splash, actionBar: actionBar),
      _ => GameLayout(
          game: game as X01Game, splashKey: splash, actionBar: actionBar),
    };

/// Résultats selon le jeu.
Widget resultsPageFor(DartsGame game,
        {Future<bool>? saving, bool tv = false}) =>
    switch (game) {
      MatchGame m => MatchResultsPage(game: m, saving: saving, tv: tv),
      PracticeGame g => PracticeResultsPage(game: g, saving: saving, tv: tv),
      CricketGame g => CricketResultsPage(game: g, saving: saving, tv: tv),
      _ => ResultsPage(game: game as X01Game, saving: saving, tv: tv),
    };

/// Affichage d'une partie : cible animée | joueur en cours (+ boutons) |
/// tableau des scores, avec les annonces animées par-dessus.
/// Utilisé par le téléphone et par l'écran TV.
class GameLayout extends StatelessWidget {
  final X01Game game;
  final GlobalKey<GameSplashState> splashKey;
  final Widget? actionBar;
  const GameLayout(
      {super.key, required this.game, required this.splashKey, this.actionBar});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final turn = game.currentTurn;
                return Padding(
                  padding: const EdgeInsets.all(6),
                  child: AnimatedDartboard(
                    size: c.maxHeight - 12,
                    hits: [
                      for (final d in turn.darts)
                        if (d.hit != null) d.hit!
                    ],
                    bust: turn.isBust,
                    win: game.finished && game.endReason == EndReason.checkout,
                    dartColor: _colorOf(game.currentPlayer),
                    targets: game.checkoutOptions.isEmpty
                        ? const []
                        : targetHits(game.checkoutOptions.first.first),
                  ),
                );
              },
            ),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Expanded(child: _CurrentPanel(game: game)),
                  if (actionBar != null) actionBar!,
                ],
              ),
            ),
            Expanded(flex: 4, child: _Scoreboard(game: game)),
          ],
        ),
        Positioned.fill(
            child: IgnorePointer(child: GameSplash(key: splashKey))),
      ],
    );
  }
}

Color _colorOf(X01Player p) => PlayerStore.instance.colorOf(p.id);

// ─── Joueur en cours (bandeau TV) ───

class _CurrentPanel extends StatelessWidget {
  final X01Game game;
  const _CurrentPanel({required this.game});

  @override
  Widget build(BuildContext context) {
    final p = game.currentPlayer;
    final st = game.currentState;
    final turn = game.currentTurn;
    final frozen = game.isFrozen(game.current);
    final freeze = game.settings.freeze;
    final color = _colorOf(p);

    String status;
    Color statusColor = Tv.text;
    Color accent = Tv.gold;
    var routes = const <List<String>>[];

    if (game.finished) {
      final names = game.winners.map((i) => game.players[i].name).join(', ');
      status = game.endReason == EndReason.checkout
          ? '🏆 $names ${game.winners.length > 1 ? 'gagnent' : 'gagne'} !'
          : '🏁 Limite atteinte : $names';
      statusColor = Tv.goldLight;
    } else if (turn.isBust) {
      status = 'BUST — ${turn.bust!.label}';
      statusColor = Tv.red;
      accent = Tv.red;
    } else if (game.turnOver) {
      status = 'Retire tes fléchettes · « Suivant »';
      statusColor = Tv.muted;
    } else if (!st.opened) {
      status = game.settings.inRule == InRule.double
          ? 'Un double pour commencer'
          : 'Double, triple ou bull pour commencer';
      statusColor = Tv.goldLight;
    } else if (frozen) {
      status = '❄ Équipe gelée : pas de fin';
      statusColor = Tv.ice;
      accent = Tv.ice;
    } else {
      routes = game.checkoutOptions;
      status = '';
      statusColor = Tv.green;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 20),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(id: p.id, name: p.name, color: color, size: 30),
              const SizedBox(width: 8),
              Flexible(
                child: Text(p.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(24)),
              ),
              if (freeze) ...[
                const SizedBox(width: 6),
                Text(kTeamNames[p.team].split(' ').last,
                    style: Tv.title(18, color: kTeamColors[p.team])),
              ],
            ],
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: Text('${st.remaining}',
                  style: Tv.title(110, color: Colors.white)),
            ),
          ),
          if (routes.isNotEmpty)
            _CheckoutRow(routes: routes)
          else
            Text(status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.title(17, color: statusColor)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: _DartSlot(
                      dart: i < turn.darts.length ? turn.darts[i] : null,
                      bust: turn.isBust),
                ),
              Container(
                width: 64,
                height: 48,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  gradient: Tv.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOTAL', style: Tv.label(10, color: Colors.black87)),
                      Text(
                          turn.isBust
                              ? '0'
                              : '${turn.darts.fold<int>(0, (s, d) => s + d.points)}',
                          style: Tv.title(22, color: Colors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fin possible : la combinaison conseillée en cases vertes, puis les autres.
class _CheckoutRow extends StatelessWidget {
  final List<List<String>> routes;
  const _CheckoutRow({required this.routes});

  @override
  Widget build(BuildContext context) {
    final main = routes.first;
    final others = routes.skip(1).map((r) => r.join(' ')).join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Tv.green,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('FIN', style: Tv.title(14, color: Colors.black)),
                ),
                const SizedBox(width: 6),
                for (final d in main)
                  Container(
                    height: 28,
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Tv.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Tv.green, width: 1.5),
                    ),
                    child: Text(d, style: Tv.title(19, color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
        if (others.isNotEmpty)
          Text('ou $others',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tv.title(14, color: Tv.muted)),
      ],
    );
  }
}

/// Zone visée par une fléchette de fin (« T20 », « D16 », « 5 », « BULL »).
List<DartHit> targetHits(String label) {
  if (label == 'BULL') return const [DartHit(25, 2, Ring.innerBull)];
  if (label == '25') return const [DartHit(25, 1, Ring.outerBull)];
  final n = int.tryParse(label.replaceFirst(RegExp('^[DT]'), ''));
  if (n == null) return const [];
  if (label.startsWith('T')) return [DartHit(n, 3, Ring.triple)];
  if (label.startsWith('D')) return [DartHit(n, 2, Ring.double)];
  return [DartHit(n, 1, Ring.singleInner), DartHit(n, 1, Ring.singleOuter)];
}

class _DartSlot extends StatelessWidget {
  final ThrownDart? dart;
  final bool bust;
  const _DartSlot({required this.dart, required this.bust});

  @override
  Widget build(BuildContext context) {
    final d = dart;
    final h = d?.hit;
    Color c = Tv.panel2;
    if (h != null) {
      if (h.multiplier == 3) c = Tv.red;
      if (h.multiplier == 2) c = Tv.green;
      if (h.isBull) c = h.ring == Ring.innerBull ? Tv.red : Tv.green;
    }
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: d == null ? Colors.black26 : c,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d == null ? Tv.line : Colors.white24),
      ),
      alignment: Alignment.center,
      child: d == null
          ? Text('—', style: Tv.title(20, color: Tv.line))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.label.toUpperCase(),
                      style: Tv.title(24).copyWith(
                          decoration:
                              bust ? TextDecoration.lineThrough : null)),
                  if (h != null && d.points != h.score)
                    Text('${d.points} PT', style: Tv.label(10, color: Tv.text)),
                ],
              ),
            ),
    );
  }
}

// ─── Tableau des scores ───

class _Scoreboard extends StatelessWidget {
  final X01Game game;
  const _Scoreboard({required this.game});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (game.settings.freeze) {
      for (final t in game.teams) {
        final frozen = game.membersOf(t).any(game.isFrozen);
        rows.add(Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kTeamColors[t].withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(kTeamNames[t].toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(16, color: kTeamColors[t])),
              ),
              if (frozen) const Text(' ❄', style: TextStyle(color: Tv.ice)),
              const Spacer(),
              Text('${game.teamRemaining(t)}', style: Tv.title(20)),
            ],
          ),
        ));
        for (final i in game.membersOf(t)) {
          rows.add(_PlayerBar(game: game, index: i));
        }
      }
    } else {
      for (var i = 0; i < game.players.length; i++) {
        rows.add(_PlayerBar(game: game, index: i));
      }
    }
    return ListView(padding: const EdgeInsets.only(top: 4), children: rows);
  }
}

class _PlayerBar extends StatelessWidget {
  final X01Game game;
  final int index;
  const _PlayerBar({required this.game, required this.index});

  @override
  Widget build(BuildContext context) {
    final p = game.players[index];
    final st = game.stateOf(index);
    final current = index == game.current && !game.finished;
    final winner = game.winners.contains(index);
    final last = game.lastTurnOf(index);

    final info = [
      'MOY ${st.average.toStringAsFixed(1)}',
      if (last != null) last.isBust ? 'BUST' : 'DERN. ${last.total}',
      if (!st.opened) 'PAS OUVERT',
    ].join('  ·  ');

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: current ? const Color(0xFF2A2210) : Tv.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? Tv.gold : Tv.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 6, color: _colorOf(p)),
          SizedBox(
            width: 22,
            child: current
                ? const Icon(Icons.play_arrow, color: Tv.gold, size: 20)
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${winner ? '🏆 ' : ''}${p.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Tv.title(19, color: current ? Tv.goldLight : Tv.text)),
                Text(info, maxLines: 1, style: Tv.label(11)),
              ],
            ),
          ),
          Container(
            width: 78,
            color: current ? Tv.gold : Colors.black,
            alignment: Alignment.center,
            child: Text('${st.remaining}',
                style: Tv.title(28, color: current ? Colors.black : Tv.text)),
          ),
        ],
      ),
    );
  }
}

// ─── Boutons ───

class _ActionBar extends StatelessWidget {
  final DartsGame game;
  final VoidCallback onUndo;
  final VoidCallback onMiss;
  final VoidCallback onNext;
  final VoidCallback onResults;

  /// Version serrée (colonne de droite du Cricket) : 2 petits boutons puis
  /// le bouton principal en dessous.
  final bool compact;
  const _ActionBar(
      {required this.game,
      required this.onUndo,
      required this.onMiss,
      required this.onNext,
      required this.onResults,
      this.compact = false});

  String get _nextLabel => game is MatchGame && (game as MatchGame).betweenLegs
      ? 'LEG SUIVANT'
      : 'SUIVANT';

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: _BarButton(
                  icon: Icons.undo,
                  label: 'ANNULER',
                  compact: true,
                  onTap: game.canUndo ? onUndo : null),
            ),
            const SizedBox(width: 3),
            if (!game.finished) ...[
              Expanded(
                child: _BarButton(
                    icon: Icons.block,
                    label: 'RATÉ',
                    compact: true,
                    onTap: game.turnOver ? null : onMiss),
              ),
              const SizedBox(width: 3),
              Expanded(
                flex: 2,
                child: _BarButton(
                    icon: Icons.skip_next,
                    label: _nextLabel,
                    primary: true,
                    compact: true,
                    onTap: onNext),
              ),
            ] else
              Expanded(
                flex: 3,
                child: _BarButton(
                    icon: Icons.emoji_events,
                    label: 'RÉSULTATS',
                    primary: true,
                    compact: true,
                    onTap: onResults),
              ),
          ],
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: Tv.panel,
        border: Border(top: BorderSide(color: Tv.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: _BarButton(
                    icon: Icons.undo,
                    label: 'ANNULER',
                    onTap: game.canUndo ? onUndo : null),
              ),
              const SizedBox(width: 8),
              if (!game.finished) ...[
                Expanded(
                  child: _BarButton(
                      icon: Icons.block,
                      label: 'RATÉ',
                      onTap: game.turnOver ? null : onMiss),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _BarButton(
                      icon: Icons.skip_next,
                      label: _nextLabel,
                      primary: true,
                      onTap: onNext),
                ),
              ] else
                Expanded(
                  flex: 3,
                  child: _BarButton(
                      icon: Icons.emoji_events,
                      label: 'RÉSULTATS',
                      primary: true,
                      onTap: onResults),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton du bas : icône au-dessus du texte (ne se coupe jamais).
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;
  const _BarButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = primary
        ? Colors.black
        : enabled
            ? Tv.text
            : Tv.line;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: compact ? 48 : 60,
        decoration: BoxDecoration(
          gradient: primary && enabled ? Tv.goldGradient : null,
          color: primary && !enabled ? Tv.goldDark : null,
          borderRadius: BorderRadius.circular(12),
          border: primary ? null : Border.all(color: Tv.line, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: compact ? 18 : (primary ? 26 : 22)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: Tv.title(
                        compact ? (primary ? 15 : 10) : (primary ? 20 : 15),
                        color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
