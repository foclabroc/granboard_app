import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio.dart';
import '../game/darts_game.dart';
import '../media.dart';
import '../players.dart';
import '../ui/dartboard.dart';
import '../ui/game_fx.dart';
import '../ui/game_page.dart' show gameView, resultsPageFor;
import '../ui/theme.dart';
import 'tv_client.dart';

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

class _TvHomeState extends State<TvHome> with SingleTickerProviderStateMixin {
  late final TvClient client =
      widget.client ?? TvClient(deviceName: widget.deviceName);
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 90))
        ..repeat();
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
    _spin.dispose();
    super.dispose();
  }

  void _onState() {
    final s = client.state;
    final colors = s?['colors'];
    if (colors is Map) {
      PlayerStore.instance.remoteColors
        ..clear()
        ..addAll({
          for (final e in colors.entries)
            '${e.key}': Color((e.value as num).toInt())
        });
    }
    // Le téléphone choisit quel appareil joue le son
    AudioService.instance.muted = s != null && s['sound'] == false;
    // … et le style de la cible
    if (s?['skin'] is String) {
      BoardSkin.current.value = BoardSkin.byId(s!['skin']);
    }
    // … et le thème de l'appli
    if (s?['theme'] is String && s!['theme'] != Tv.skin.value.id) {
      Tv.choose(AppSkin.byId(s['theme']));
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
    } else if (screen == 'lobby') {
      body = _Lobby(spin: _spin, host: '${s?['host'] ?? ''}', client: client);
    } else {
      body = _CodeScreen(
          spin: _spin,
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
  final Animation<double> spin;
  final TvClient client;
  final VoidCallback? onPhoneMode;
  final String deviceName;
  const _CodeScreen(
      {required this.spin,
      required this.client,
      required this.deviceName,
      this.onPhoneMode});

  @override
  Widget build(BuildContext context) {
    final code = client.code;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: LayoutBuilder(
              builder: (context, c) => RotationTransition(
                turns: spin,
                child: Dartboard(
                    size: (c.maxHeight * 0.8).clamp(100.0, c.maxWidth * 0.9)),
              ),
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
  final Animation<double> spin;
  final String host;
  final TvClient client;
  const _Lobby({required this.spin, required this.host, required this.client});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LayoutBuilder(
                builder: (context, c) => RotationTransition(
                  turns: spin,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Tv.gold.withValues(alpha: 0.25),
                            blurRadius: 80,
                            spreadRadius: 6)
                      ],
                    ),
                    child: Dartboard(
                        size: (MediaQuery.sizeOf(context).height * 0.5)
                            .clamp(100.0, 600.0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (r) => Tv.goldGradient.createShader(r),
                child: Text('FOCLABOARD',
                    style: Tv.title(52, color: Colors.white)
                        .copyWith(letterSpacing: 5)),
              ),
              const SizedBox(height: 6),
              Text(
                host.isEmpty
                    ? 'EN ATTENTE D\'UNE PARTIE…'
                    : 'RELIÉ À ${host.toUpperCase()} · EN ATTENTE D\'UNE PARTIE…',
                style: Tv.label(18, color: Tv.text),
              ),
            ],
          ),
        ),
        Positioned(right: 16, bottom: 12, child: _Corner(client: client)),
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
      _fx.afterAction(g, a);
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
                child: Text(g.rulesLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.label(14)),
              ),
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
