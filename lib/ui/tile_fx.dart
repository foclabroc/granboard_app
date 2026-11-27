// Effets communs aux tuiles de l'appli : reflet qui balaie la tuile
// (décalé d'une tuile à l'autre, comme une vague) et petit enfoncement au
// toucher. Une seule horloge pour toutes les tuiles ; rien d'animé en
// Perf.lite (écran TV) ni en test.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

class _TileClock extends ValueNotifier<double> {
  _TileClock() : super(0);
  static final instance = _TileClock();
  Ticker? _ticker;
  int _users = 0;

  void use() {
    if (_users++ == 0) {
      _ticker = Ticker((d) => value = d.inMicroseconds / 1e6)..start();
    }
  }

  void release() {
    if (--_users == 0) {
      _ticker?.dispose();
      _ticker = null;
    }
  }
}

class TileFx extends StatefulWidget {
  final Widget child;
  final double radius;

  /// Texte qui fixe le décalage du reflet (titre, clé…).
  final String seed;

  /// Intensité du reflet (0,22 pour les grandes tuiles).
  final double shine;

  /// Marge autour de la tuile (le reflet reste sur la tuile).
  final EdgeInsets margin;
  const TileFx(
      {super.key,
      required this.child,
      required this.seed,
      this.radius = 12,
      this.shine = .2,
      this.margin = EdgeInsets.zero});

  /// Coupé dans les tests (horloge qui tourne sans fin).
  static bool enabled = true;

  /// Durée d'un tour de reflet (s).
  static const period = 6.0;

  @override
  State<TileFx> createState() => _TileFxState();
}

class _TileFxState extends State<TileFx> {
  bool _down = false;
  bool _clock = false;

  bool get _anim => TileFx.enabled && !Perf.lite && widget.shine > 0;

  double get _phase =>
      (widget.seed.hashCode.abs() % 1000) / 1000 * TileFx.period;

  @override
  void initState() {
    super.initState();
    if (_anim) {
      _clock = true;
      _TileClock.instance.use();
    }
  }

  @override
  void dispose() {
    if (_clock) _TileClock.instance.release();
    super.dispose();
  }

  void _press(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final fx = Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: _down ? .95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (_clock)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: ValueListenableBuilder<double>(
                        valueListenable: _TileClock.instance,
                        builder: (context, t, _) {
                          // reflet pendant 1,2 s sur chaque tour
                          final k = ((t + _phase) % TileFx.period) / 1.2;
                          if (k > 1) return const SizedBox();
                          final x = -1.8 + k * 3.6;
                          final a = widget.shine;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(x - .6, -1),
                                end: Alignment(x + .6, 1),
                                colors: [
                                  const Color(0x00FFFFFF),
                                  Color.fromRGBO(255, 255, 255, a),
                                  const Color(0x00FFFFFF),
                                ],
                                stops: const [.35, .5, .65],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return widget.margin == EdgeInsets.zero
        ? fx
        : Padding(padding: widget.margin, child: fx);
  }
}
