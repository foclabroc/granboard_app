import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../audio.dart';
import '../granboard.dart';

/// Coups réussis fêtés par une animation plein écran.
enum Award {
  lowTon('lowton', 'LOW TON'),
  highTon('highton', 'HIGH TON'),
  ton80('ton80', 'TON 80'),
  hatTrick('hat_trick', 'HAT TRICK'),
  threeInTheBlack('3_in_the_black', '3 IN THE BLACK'),
  threeInABed('3_in_a_bed', '3 IN A BED'),
  whiteHorse('white_horse', 'WHITE HORSE');

  final String slug;
  final String label;
  const Award(this.slug, this.label);

  /// Styles disponibles (fichiers `assets/awards/<style>_<slug>.mp4`).
  List<String> get styles => this == Award.threeInABed
      ? const ['glitch', 'rose']
      : const ['glitch', 'neon', 'rose'];

  /// Une animation au hasard parmi les styles de ce coup.
  String randomAsset([Random? random]) {
    final s = styles[(random ?? _random).nextInt(styles.length)];
    return 'assets/awards/${s}_$slug.mp4';
  }

  static final _random = Random();
}

/// Coup réussi d'une manche de 3 fléchettes, ou null.
///
/// Par les fléchettes : 3 IN THE BLACK (3 bulls au centre), HAT TRICK
/// (3 bulls), WHITE HORSE (3 triples sur 3 numéros différents, si
/// [whiteHorse]), 3 IN A BED (3 fois le même double ou le même triple).
/// Par le total de la manche, si [total] est donné (01) : TON 80 (180),
/// HIGH TON (151 à 179), LOW TON (100 à 150).
Award? awardOf(List<DartHit?> darts, {int? total, bool whiteHorse = false}) {
  if (darts.length != 3) return null;
  final hits = darts.whereType<DartHit>().toList();
  if (hits.length == 3) {
    if (hits.every((h) => h.ring == Ring.innerBull)) {
      return Award.threeInTheBlack;
    }
    if (hits.every((h) => h.isBull)) return Award.hatTrick;
    if (total == 180) return Award.ton80;
    final triples = {
      for (final h in hits)
        if (h.ring == Ring.triple) h.number
    };
    if (whiteHorse && triples.length == 3) return Award.whiteHorse;
    final first = hits.first;
    if ((first.ring == Ring.triple || first.ring == Ring.double) &&
        hits.every((h) => h.number == first.number && h.ring == first.ring)) {
      return Award.threeInABed;
    }
  }
  if (total == null) return null;
  if (total == 180) return Award.ton80;
  if (total > 150) return Award.highTon;
  if (total >= 100) return Award.lowTon;
  return null;
}

/// Fléchettes fêtées une par une par une animation courte (1,5 s).
enum HitClip {
  triple20('t20'),
  bull('bull'),
  doubleBull('dbull');

  final String slug;
  const HitClip(this.slug);

  /// Fonds disponibles (fichiers `assets/hits/<fond>_<slug>.mp4`).
  static const styles = ['fire', 'ring'];

  String randomAsset([Random? random]) {
    final s = styles[(random ?? Award._random).nextInt(styles.length)];
    return 'assets/hits/${s}_$slug.mp4';
  }

  /// Animation de la fléchette [hit], ou null.
  static HitClip? of(DartHit? hit) {
    if (hit == null) return null;
    if (hit.ring == Ring.innerBull) return HitClip.doubleBull;
    if (hit.isBull) return HitClip.bull;
    if (hit.number == 20 && hit.ring == Ring.triple) return HitClip.triple20;
    return null;
  }
}

/// Joue les animations par-dessus tout l'écran (téléphone et TV). Une seule
/// à la fois ; on la passe en touchant l'écran, et elle s'arrête quand la
/// partie continue.
class AwardPlayer {
  AwardPlayer._();

  /// Faux en test (pas de lecteur vidéo).
  static bool enabled = true;

  static OverlayEntry? _entry;

  /// Lance l'animation de [award]. Renvoie faux si elle ne peut pas être
  /// affichée (l'appelant garde alors son annonce habituelle).
  static bool play(BuildContext? context, Award award) =>
      playAsset(context, award.randomAsset());

  /// Une animation est à l'écran.
  static bool get active => _entry != null;

  /// Lance la vidéo [asset] (voir [play]). [opacity] < 1 laisse deviner la
  /// partie derrière.
  static bool playAsset(BuildContext? context, String asset,
      {double opacity = 1}) {
    if (!enabled || context == null) return false;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;
    stop();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AwardVideo(
        asset: asset,
        opacity: opacity,
        onDone: () {
          if (identical(_entry, entry)) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    return true;
  }

  /// Arrête l'animation en cours (joueur suivant, annulation, écran quitté).
  static void stop() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _AwardVideo extends StatefulWidget {
  final String asset;
  final double opacity;
  final VoidCallback onDone;
  const _AwardVideo(
      {required this.asset, required this.onDone, this.opacity = 1});

  @override
  State<_AwardVideo> createState() => _AwardVideoState();
}

class _AwardVideoState extends State<_AwardVideo> {
  VideoPlayerController? _c;
  Timer? _guard;
  bool _ready = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Secours : jamais plus de 10 s à l'écran, même si la lecture cale
    _guard = Timer(const Duration(seconds: 10), _close);
    _start();
  }

  Future<void> _start() async {
    try {
      final c = VideoPlayerController.asset(widget.asset,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _c = c;
      await c.initialize();
      if (!mounted) return;
      final audio = AudioService.instance;
      await c.setVolume(audio.muted || !audio.effects ? 0 : 1);
      c.addListener(_watch);
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _close();
    }
  }

  void _watch() {
    final v = _c?.value;
    if (v == null) return;
    if (v.hasError ||
        (v.duration > Duration.zero &&
            v.position >= v.duration - const Duration(milliseconds: 120))) {
      _close();
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _guard?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _guard?.cancel();
    _c?.removeListener(_watch);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    // Tant que la vidéo n'est pas prête, l'écran reste utilisable
    return IgnorePointer(
      ignoring: !_ready,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: AnimatedOpacity(
          opacity: _ready ? widget.opacity : 0,
          duration: const Duration(milliseconds: 150),
          child: ColoredBox(
            color: Colors.black,
            child: Center(
              child: c == null || !_ready
                  ? const SizedBox.shrink()
                  : AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
