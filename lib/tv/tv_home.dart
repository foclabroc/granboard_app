import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio.dart';
import '../game/darts_game.dart';
import '../media.dart';
import '../players.dart';
import '../ui/cricket_view.dart' show CricketStyle;
import '../ui/dartboard.dart';
import '../ui/game_fx.dart';
import '../ui/game_page.dart' show NextMatchChip, gameView, resultsPageFor;
import '../tournament.dart';
import '../ui/theme.dart';
import '../ui/wallpaper.dart';
import '../ui/tournament_page.dart' show TvTournamentView;
import 'tv_client.dart';
import 'next_up.dart';
import 'tv_idle.dart';

/// Écran TV : affiche le code du salon, puis ce que le téléphone envoie
/// (attente, partie, résultats). Tout se pilote depuis le téléphone.
class TvHome extends StatefulWidget {
  final TvClient? client; // injecté en test
  final VoidCallback? onPhoneMode; // « utiliser en mode téléphone »
  final String deviceName; // « TV » ou « Tablette »
  const TvHome(
      {super.key, this.client, this.onPhoneMode, this.deviceName = 'TV'});

  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  late final TvClient client =
      widget.client ?? TvClient(deviceName: widget.deviceName);
  String? _screen;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
    client.addListener(_onState);
    if (widget.client == null) client.start();
    AudioService.instance.startMusic();
  }

  @override
  void dispose() {
    client.removeListener(_onState);
    if (widget.client == null) client.dispose();
    super.dispose();
  }

  void _onState() {
    final s = client.state;
    final colors = s?['colors'];
    if (colors is Map) {
      final sent = {
        for (final e in colors.entries)
          '${e.key}': Color((e.value as num).toInt())
      };
      // Les couleurs de la partie, telles que le téléphone les a choisies
      PlayerStore.instance.remoteColors
        ..clear()
        ..addAll(sent);
      PlayerStore.instance.gameColors
        ..clear()
        ..addAll(sent);
    }
    if (colors is Map) {
      PlayerStore.instance.ensureRatings(colors.keys.map((k) => '$k'));
    }
    // Le téléphone choisit quel appareil joue le son
    AudioService.instance.muted = s != null && s['sound'] == false;
    // … et le style de la cible
    if (s?['skin'] is String) {
      BoardSkin.current.value = BoardSkin.byId(s!['skin']);
    }
    // … et la mise en page du Cricket
    if (s?['cricket'] is String) {
      CricketStyle.current.value = CricketStyle.fix(s!['cricket']);
    }
    // … et le thème de l'appli
    if (s?['theme'] is String && s!['theme'] != Tv.skin.value.id) {
      Tv.choose(AppSkin.byId(s['theme']));
    }
    if (s?['wall'] is String) Wallpaper.instance.applyFromPhone(s!['wall']);
    if (s?['calls'] is bool) AudioService.instance.dartCalls = s!['calls'];
    if (s?['pron'] is Map) {
      AudioService.instance.pronunciations
        ..clear()
        ..addAll((s!['pron'] as Map).map((k, v) => MapEntry('$k', '$v')));
    }
    final screen = s?['screen'] as String?;
    if (screen != _screen) {
      _screen = screen;
      if (screen == 'game') {
        AudioService.instance.stopMusic();
      } else {
        AudioService.instance.startMusic();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = client.state;
    final screen = s?['screen'];
    Widget body;
    if (screen == 'game' && s?['game'] is Map) {
      body = _TvGame(state: s!, code: client.code);
    } else if (screen == 'results' && s?['game'] is Map) {
      body = KeyedSubtree(
        key: ValueKey(jsonEncode(s!['game']).hashCode),
        child: resultsPageFor(
            gameFromJson(Map<String, dynamic>.from(s['game'] as Map)),
            tv: true),
      );
    } else if (screen == 'tournament' && s?['tournament'] is Map) {
      body = TvTournamentView(
          tournament: Tournament.fromJson(
              Map<String, dynamic>.from(s!['tournament'] as Map)));
    } else if (screen == 'lobby') {
      body = _Lobby(
          host: '${s?['host'] ?? ''}',
          ids: [
            for (final i in (s?['ids'] as List?) ?? const [])
              if (i is num) i.toInt()
          ],
          client: client);
    } else {
      body = _CodeScreen(
          client: client,
          deviceName: widget.deviceName,
          onPhoneMode: widget.onPhoneMode);
    }
    return Scaffold(
      body: TvBackground(child: SafeArea(child: body)),
    );
  }
}

// ─── Code à entrer sur le téléphone ───

class _CodeScreen extends StatelessWidget {
  final TvClient client;
  final VoidCallback? onPhoneMode;
  final String deviceName;
  const _CodeScreen(
      {required this.client, required this.deviceName, this.onPhoneMode});

  @override
  Widget build(BuildContext context) {
    final code = client.code;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: LayoutBuilder(
              builder: (context, c) => FloatingBoard(
                  size: (c.maxHeight * 0.7).clamp(100.0, c.maxWidth * 0.9)),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(right: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => Tv.goldGradient.createShader(r),
                  child: Text('FOCLABOARD',
                      style: Tv.title(56, color: Colors.white)
                          .copyWith(letterSpacing: 5)),
                ),
                Text('ÉCRAN ${deviceName.toUpperCase()}',
                    style: Tv.label(18, color: Tv.text)),
                const SizedBox(height: 24),
                if (code == null)
                  Text(client.error ?? 'Connexion au serveur…',
                      style: Tv.title(24, color: Tv.red))
                else ...[
                  if (client.lanOnly)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                          'SANS INTERNET : LE TÉLÉPHONE DOIT ÊTRE SUR LE MÊME WI-FI',
                          maxLines: 2,
                          style: Tv.label(15, color: Tv.goldLight)),
                    ),
                  Text('SUR LE TÉLÉPHONE : ACCUEIL › TV › ENTRE CE CODE',
                      maxLines: 2, style: Tv.label(15, color: Tv.muted)),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        for (final ch in code.split(''))
                          Container(
                            width: 84,
                            height: 104,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Tv.gold, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Tv.gold.withValues(alpha: 0.3),
                                    blurRadius: 24)
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(ch,
                                style: Tv.title(72, color: Tv.goldLight)),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      autofocus: true,
                      onPressed: client.newCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('NOUVEAU CODE'),
                    ),
                    if (onPhoneMode != null) ...[
                      TextButton.icon(
                        onPressed: onPhoneMode,
                        icon: const Icon(Icons.smartphone),
                        label: const Text('MODE TÉLÉPHONE'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Attente d'une partie ───

class _Lobby extends StatelessWidget {
  final String host;
  final List<int> ids;
  final TvClient client;
  const _Lobby({required this.host, required this.ids, required this.client});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(flex: 3, child: TvTopPanel()),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, c) => FloatingBoard(
                            size: min(c.maxHeight * 0.85, c.maxWidth * 0.8)
                                .clamp(80.0, h * 0.55)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ShaderMask(
                        shaderCallback: (r) => Tv.goldGradient.createShader(r),
                        child: Text('FOCLABOARD',
                            style: Tv.title(48, color: Colors.white)
                                .copyWith(letterSpacing: 5)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        host.isEmpty
                            ? 'EN ATTENTE D\'UNE PARTIE…'
                            : 'RELIÉ À ${host.toUpperCase()} · EN ATTENTE D\'UNE PARTIE…',
                        style: Tv.label(16, color: Tv.text),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 3, child: TvRecentPanel(ids: ids)),
            ],
          ),
        ),
        Positioned(right: 16, bottom: 10, child: _Corner(client: client)),
      ],
    );
  }
}

/// Code et état du relais, en petit dans un coin.
class _Corner extends StatelessWidget {
  final TvClient client;
  const _Corner({required this.client});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: client.live ? Tv.green : Tv.gold),
        const SizedBox(width: 6),
        Text('CODE ${client.code ?? '—'}', style: Tv.label(13)),
      ],
    );
  }
}

// ─── Partie : rejoue les actions envoyées par le téléphone ───

class _TvGame extends StatefulWidget {
  final Map<String, dynamic> state;
  final String? code;
  const _TvGame({required this.state, this.code});

  @override
  State<_TvGame> createState() => _TvGameState();
}

class _TvGameState extends State<_TvGame> {
  final _splash = GlobalKey<GameSplashState>();
  late final _fx = GameFx(_splash, haptics: false);
  DartsGame? _game;
  String? _sig;

  @override
  void initState() {
    super.initState();
    _update(first: true);
  }

  @override
  void didUpdateWidget(_TvGame old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state)) _update();
  }

  /// Applique les nouvelles actions une à une ; effets seulement pour la
  /// dernière (pas de rafale de sons après une coupure).
  void _update({bool first = false}) {
    final j = Map<String, dynamic>.from(widget.state['game'] as Map);
    final sig = jsonEncode({'s': j['settings'], 'p': j['players']});
    final actions = [for (final a in (j['actions'] as List? ?? const [])) '$a'];
    final g = _game;
    if (g == null || sig != _sig) {
      _sig = sig;
      _game = gameFromJson(j);
      MediaStore.instance.ensure(_game!.players.map((p) => p.id));
      if (actions.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fx.start(_game!));
      }
      return;
    }
    final old = g.actionLog;
    final extends_ = actions.length >= old.length &&
        List.generate(old.length, (i) => old[i] == actions[i]).every((x) => x);
    if (!extends_) {
      _game = gameFromJson(j); // annulation côté téléphone : sans effet
      return;
    }
    for (var i = old.length; i < actions.length; i++) {
      final a = actions[i];
      if (!g.applyLogEntry(a) || i != actions.length - 1 || first) continue;
      // Après l'image en cours : _update tourne pendant la construction de
      // l'écran, où ni la vidéo (Overlay) ni les annonces ne peuvent
      // s'afficher
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_game, g)) _fx.afterAction(g, a);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _game!;
    final limit = g.roundLimit;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Row(
            children: [
              Text(g.title.toUpperCase(), style: Tv.title(30, color: Tv.gold)),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Text(g.rulesLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.label(14)),
              ),
              Flexible(flex: 3, child: NextUpChip(game: g, scale: 1.2)),
              const SizedBox(width: 12),
              if (widget.state['next'] is String && !g.finished) ...[
                NextMatchChip(text: widget.state['next'] as String, scale: 1.3),
                const SizedBox(width: 16),
              ],
              Text(
                limit == null
                    ? 'MANCHE ${g.round}'
                    : 'MANCHE ${g.round}/$limit',
                style: Tv.title(22),
              ),
              const SizedBox(width: 16),
              Text('CODE ${widget.code ?? ''}', style: Tv.label(12)),
            ],
          ),
        ),
        Expanded(child: gameView(g, _splash)),
      ],
    );
  }
}
