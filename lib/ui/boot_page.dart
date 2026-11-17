// Écran de démarrage : petite barre de chargement pendant qu'on prépare
// tout ce qui ferait attendre en partie (annonces copiées hors de l'APK,
// bruitages, images décodées, effets graphiques compilés).

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../granboard.dart';
import '../media.dart';
import '../players.dart';
import 'dartboard.dart';
import 'game_fx.dart';
import 'theme.dart';
import 'wallpaper.dart';

/// Photos des joueurs d'une partie décodées d'avance (après leur
/// téléchargement) : le bandeau du tour et le tableau des scores ne calent
/// pas à leur 1re apparition.
Future<void> warmPlayers(BuildContext context, Iterable<String> ids) async {
  final list = ids.toList();
  await MediaStore.instance.ensure(list);
  if (!context.mounted) return;
  for (final id in list) {
    final img = MediaStore.instance.imageOf(id);
    if (img != null) precacheImage(img, context, onError: (e, s) {});
  }
}

/// Affiche l'écran de chargement, puis [child].
class BootGate extends StatefulWidget {
  /// Faux en test : [child] tout de suite.
  static bool enabled = true;

  final Widget child;
  const BootGate({super.key, required this.child});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late bool _done = !BootGate.enabled;
  double _progress = 0;
  String _step = 'Démarrage…';
  final _splash = GlobalKey<GameSplashState>();

  @override
  void initState() {
    super.initState();
    if (!_done) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  void _set(double p, String step) {
    if (!mounted) return;
    setState(() {
      _progress = p.clamp(0.0, 1.0);
      _step = step;
    });
  }

  Future<void> _run() async {
    final started = DateTime.now();
    final audio = AudioService.instance;
    // Jamais bloqué plus de 25 s : l'accueil s'ouvre quoi qu'il arrive
    final guard = Timer(const Duration(seconds: 25), _finish);
    try {
      // 1. Annonces (le plus long, seulement après une mise à jour qui
      //    change les voix)
      _set(0.02, 'Préparation des annonces…');
      await audio.prepareVoiceFiles((p) => _set(0.02 + p * 0.68, 'Préparation des annonces…'));
      // 2. Bruitages et sons des joueurs
      _set(0.72, 'Préparation des sons…');
      await audio.prepareSounds();
      // 3. Images : décodées d'avance (photos, avatars, fond d'écran)
      _set(0.8, 'Préparation des images…');
      if (mounted) await _images();
      // 4. Effets graphiques : la cible animée et le grand texte des coups
      //    sont dessinés derrière la barre (shaders préparés avant la
      //    partie) ; pseudos des comptes du téléphone enregistrés
      _set(0.9, 'Préparation des effets…');
      _splash.currentState?.show('180', Tv.gold, big: true);
      audio.names = [for (final p in PlayerStore.instance.players) p.name];
      final spent = DateTime.now().difference(started);
      const warm = Duration(milliseconds: 900);
      if (spent < warm) await Future<void>.delayed(warm - spent);
      _set(1, 'Prêt !');
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (_) {}
    guard.cancel();
    _finish();
  }

  Future<void> _images() async {
    final ctx = context;
    final providers = <ImageProvider>[
      for (final a in kAvatars) AssetImage(avatarAsset(a)),
      Wallpaper.instance.current,
      for (final id in MediaStore.instance.ids)
        if (MediaStore.instance.imageOf(id) case final img?) img,
    ];
    await Future.wait([
      for (final p in providers)
        precacheImage(p, ctx, onError: (e, s) {})
            .timeout(const Duration(seconds: 3), onTimeout: () {}),
    ]);
  }

  void _finish() {
    if (mounted && !_done) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Presque invisible : dessiné pour de vrai, donc effets préparés
          Opacity(
            opacity: 0.02,
            child: Stack(
              children: [
                Center(
                  child: AnimatedDartboard(
                    size: 220,
                    hits: const [
                      DartHit(20, 3, Ring.triple),
                      DartHit(25, 2, Ring.innerBull),
                    ],
                    targets: const [DartHit(16, 2, Ring.double)],
                    dartColor: Tv.gold,
                  ),
                ),
                Positioned.fill(child: GameSplash(key: _splash)),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(420, w * 0.7)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => Tv.goldGradient.createShader(r),
                    child: Text('FOCLABOARD',
                        style: Tv.title(44, color: Colors.white)
                            .copyWith(letterSpacing: 5)),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: const ValueKey('boot-progress'),
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: Tv.panel,
                      color: Tv.gold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_step.toUpperCase(),
                      style: Tv.label(13, color: Tv.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
