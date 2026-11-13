import 'package:flutter/material.dart';

import '../players.dart';
import 'theme.dart';
import 'widgets.dart';

/// Bandeau « au tour de … » qui traverse l'écran quand on passe au joueur
/// suivant (téléphone et TV). Ne bloque pas l'écran : on peut lancer tout
/// de suite.
class TurnBanner {
  TurnBanner._();

  /// Faux en test (le nom du joueur serait affiché deux fois).
  static bool enabled = true;

  static OverlayEntry? _entry;

  static void show(BuildContext? context,
      {required String id, required String name, String? sub}) {
    if (!enabled || context == null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Banner(
        id: id,
        name: name,
        sub: sub,
        color: PlayerStore.instance.colorOf(id),
        onDone: () {
          if (identical(_entry, entry)) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _Banner extends StatefulWidget {
  final String id;
  final String name;
  final String? sub;
  final Color color;
  final VoidCallback onDone;
  const _Banner(
      {required this.id,
      required this.name,
      required this.color,
      required this.onDone,
      this.sub});

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    // Material : sans lui, le texte d'un Overlay est souligné en jaune
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: _animated(color),
      ),
    );
  }

  Widget _animated(Color color) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // 3 s : entrée par la gauche (0,3 s), pause, sortie par la droite
          // (0,3 s)
          final dx = t < 0.1
              ? -1 + Curves.easeOutCubic.transform(t / 0.1)
              : t > 0.9
                  ? Curves.easeInCubic.transform((t - 0.9) / 0.1)
                  : 0.0;
          final fade = t < 0.05
              ? t / 0.05
              : t > 0.925
                  ? (1 - t) / 0.075
                  : 1.0;
          return Stack(
            children: [
              // Voile léger derrière le bandeau
              Positioned.fill(
                child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35 * fade)),
              ),
              Center(
                child: FractionalTranslation(
                  translation: Offset(dx, 0),
                  child: Opacity(opacity: fade.clamp(0, 1), child: child),
                ),
              ),
              // Trait lumineux qui file en sens inverse
              Align(
                alignment:
                    Alignment(1.4 - 2.8 * Curves.easeOut.transform(t), 0),
                child: Container(
                  width: 140,
                  height: 3,
                  margin: const EdgeInsets.only(top: 104),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.9 * fade),
                      color.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ],
          );
        },
        child: Transform(
          transform: Matrix4.skewX(-0.18),
          alignment: Alignment.center,
          child: Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0),
                  Color.lerp(color, Colors.black, 0.35)!,
                  Color.lerp(color, Colors.black, 0.6)!,
                  Colors.black.withValues(alpha: 0),
                ],
                stops: const [0, 0.22, 0.78, 1],
              ),
              border: Border.symmetric(
                horizontal: BorderSide(
                    color: Colors.white.withValues(alpha: 0.75), width: 2),
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 30),
              ],
            ),
            child: Transform(
              transform: Matrix4.skewX(0.18),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: PlayerAvatar(
                        name: widget.name,
                        color: color,
                        size: 62,
                        id: widget.id),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.sub ?? 'AU TOUR DE',
                            style: Tv.label(14, color: Colors.white70)
                                .copyWith(letterSpacing: 3)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(widget.name.toUpperCase(),
                              maxLines: 1,
                              style: Tv.title(54).copyWith(shadows: const [
                                Shadow(color: Colors.black, blurRadius: 10),
                              ])),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: RankChip(widget.id, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
