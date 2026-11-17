import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallpaper.dart';

/// Animation du fond d'un thème.
enum SkinFx {
  spotlight,
  grid,
  petals,
  embers,
  wallpaper,
  snow,
  bokeh,
  sunset,
  bubbles,
  stars,
  carbon,
  // Thèmes des jeux (game_theme.dart)
  arena,
  chalk,
  duel,
  hud,
  confetti,
  lanes,
  fairway,
  pitch,
  paws,
  splats,
  clock,
}

/// Thème de l'appli : couleurs + fond animé. Choisi dans l'accueil (⋮ ›
/// Thème), mémorisé, envoyé aux écrans TV reliés.
class AppSkin {
  final String id;
  final String name;
  final Color bg;
  final Color panel;
  final Color panel2;
  final Color line;

  /// Couleur d'accent (l'« or » du thème d'origine) et ses 2 nuances.
  final Color accent;
  final Color accentLight;
  final Color accentDark;

  /// Seconde couleur des lueurs du fond.
  final Color glow;
  final Color muted;
  final List<Color> panelColors;
  final SkinFx fx;
  const AppSkin({
    required this.id,
    required this.name,
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.line,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.glow,
    required this.muted,
    required this.panelColors,
    required this.fx,
  });

  static const gold = AppSkin(
    id: 'gold',
    name: 'Retransmission',
    bg: Color(0xFF07070A),
    panel: Color(0xFF121218),
    panel2: Color(0xFF1B1B23),
    line: Color(0xFF2A2A35),
    accent: Color(0xFFE8B63C),
    accentLight: Color(0xFFFFD877),
    accentDark: Color(0xFF8C6716),
    glow: Color(0xFFD7262F),
    muted: Color(0xFF8D8D9C),
    panelColors: [Color(0xFF1D1D26), Color(0xFF0E0E13)],
    fx: SkinFx.spotlight,
  );

  static const neon = AppSkin(
    id: 'neon',
    name: 'Néon',
    bg: Color(0xFF05061A),
    panel: Color(0xFF0D1030),
    panel2: Color(0xFF161A45),
    line: Color(0xFF2A3070),
    accent: Color(0xFF2DE2FF),
    accentLight: Color(0xFFA6F4FF),
    accentDark: Color(0xFF0A7D94),
    glow: Color(0xFFFF2BD6),
    muted: Color(0xFF8C93C8),
    panelColors: [Color(0xFF181C4C), Color(0xFF0A0C26)],
    fx: SkinFx.grid,
  );

  static const sakura = AppSkin(
    id: 'sakura',
    name: 'Sakura',
    bg: Color(0xFF12060F),
    panel: Color(0xFF22101F),
    panel2: Color(0xFF32182E),
    line: Color(0xFF55284C),
    accent: Color(0xFFFF7EB6),
    accentLight: Color(0xFFFFC2DD),
    accentDark: Color(0xFF9C2E62),
    glow: Color(0xFF9B5CFF),
    muted: Color(0xFFB392AC),
    panelColors: [Color(0xFF3A1B35), Color(0xFF190B17)],
    fx: SkinFx.petals,
  );

  static const ember = AppSkin(
    id: 'ember',
    name: 'Braise',
    bg: Color(0xFF0E0704),
    panel: Color(0xFF1E110A),
    panel2: Color(0xFF2C1A10),
    line: Color(0xFF4A2D1B),
    accent: Color(0xFFFF8A2B),
    accentLight: Color(0xFFFFC27A),
    accentDark: Color(0xFF9A4208),
    glow: Color(0xFFFF3B1F),
    muted: Color(0xFFB09886),
    panelColors: [Color(0xFF34200F), Color(0xFF160C06)],
    fx: SkinFx.embers,
  );

  /// Fond d'écran : une image (de l'appli, au hasard ou du téléphone,
  /// voir [Wallpaper]) assombrie, panneaux légèrement transparents.
  static const wallpaper = AppSkin(
    id: 'wallpaper',
    name: 'Fond d\'écran',
    bg: Color(0xFF07070A),
    panel: Color(0xD9121218),
    panel2: Color(0xE01B1B23),
    line: Color(0xFF34343F),
    accent: Color(0xFFE8B63C),
    accentLight: Color(0xFFFFD877),
    accentDark: Color(0xFF8C6716),
    glow: Color(0xFF2D7DFF),
    muted: Color(0xFFA3A3B2),
    panelColors: [Color(0xD91D1D26), Color(0xD90E0E13)],
    fx: SkinFx.wallpaper,
  );

  static const ice = AppSkin(
    id: 'ice',
    name: 'Glace',
    bg: Color(0xFF050B12),
    panel: Color(0xFF0D1824),
    panel2: Color(0xFF15243A),
    line: Color(0xFF24405C),
    accent: Color(0xFF8FE3FF),
    accentLight: Color(0xFFE0F7FF),
    accentDark: Color(0xFF2C7FA0),
    glow: Color(0xFF4C7DFF),
    muted: Color(0xFF8FA6BC),
    panelColors: [Color(0xFF16273B), Color(0xFF08111C)],
    fx: SkinFx.snow,
  );

  static const pub = AppSkin(
    id: 'pub',
    name: 'Pub',
    bg: Color(0xFF06100B),
    panel: Color(0xFF0F1D15),
    panel2: Color(0xFF16291E),
    line: Color(0xFF27442F),
    accent: Color(0xFFD9B44A),
    accentLight: Color(0xFFF4DB8E),
    accentDark: Color(0xFF7E6220),
    glow: Color(0xFF1FA35A),
    muted: Color(0xFF94A898),
    panelColors: [Color(0xFF1B3122), Color(0xFF0A140E)],
    fx: SkinFx.bokeh,
  );

  static const synthwave = AppSkin(
    id: 'synthwave',
    name: 'Synthwave',
    bg: Color(0xFF0B0418),
    panel: Color(0xFF180B2E),
    panel2: Color(0xFF241242),
    line: Color(0xFF3D2266),
    accent: Color(0xFFFF6AD5),
    accentLight: Color(0xFFFFB8EC),
    accentDark: Color(0xFF9B1F7E),
    glow: Color(0xFFFF9E2C),
    muted: Color(0xFFA394C4),
    panelColors: [Color(0xFF2A1450), Color(0xFF110726)],
    fx: SkinFx.sunset,
  );

  static const abyss = AppSkin(
    id: 'abyss',
    name: 'Abysses',
    bg: Color(0xFF020A12),
    panel: Color(0xFF061826),
    panel2: Color(0xFF0A2336),
    line: Color(0xFF12405A),
    accent: Color(0xFF2FD0C0),
    accentLight: Color(0xFF9DF2E8),
    accentDark: Color(0xFF0D7A70),
    glow: Color(0xFF1E5BFF),
    muted: Color(0xFF86A7B5),
    panelColors: [Color(0xFF0B2A3D), Color(0xFF041019)],
    fx: SkinFx.bubbles,
  );

  static const galaxy = AppSkin(
    id: 'galaxy',
    name: 'Galaxie',
    bg: Color(0xFF04030C),
    panel: Color(0xFF0F0C22),
    panel2: Color(0xFF181433),
    line: Color(0xFF2C2655),
    accent: Color(0xFFB48CFF),
    accentLight: Color(0xFFE2D4FF),
    accentDark: Color(0xFF5B3BB0),
    glow: Color(0xFF3FA9FF),
    muted: Color(0xFF9A95B8),
    panelColors: [Color(0xFF1D1840), Color(0xFF0A0819)],
    fx: SkinFx.stars,
  );

  static const carbon = AppSkin(
    id: 'carbon',
    name: 'Carbone',
    bg: Color(0xFF08080A),
    panel: Color(0xFF141417),
    panel2: Color(0xFF1D1D21),
    line: Color(0xFF2E2E34),
    accent: Color(0xFFFF3B3B),
    accentLight: Color(0xFFFF9A8F),
    accentDark: Color(0xFF8F1414),
    glow: Color(0xFF6B6B78),
    muted: Color(0xFF8E8E98),
    panelColors: [Color(0xFF202024), Color(0xFF0D0D10)],
    fx: SkinFx.carbon,
  );

  static const all = [
    gold,
    neon,
    sakura,
    ember,
    ice,
    pub,
    synthwave,
    abyss,
    galaxy,
    carbon,
    wallpaper,
  ];

  static AppSkin byId(Object? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => gold);
}

/// Économie d'animations pour les appareils peu puissants (écran TV) :
/// fond fixe, cible sans animation continue (LED, reflet, zones qui
/// pulsent) ; les animations d'un coup (fléchette, bust, victoire) restent.
class Perf {
  /// Réglé depuis le téléphone (fenêtre TV › « Animations complètes ») ;
  /// les animations en cours s'arrêtent ou reprennent aussitôt.
  static final liteNotifier = ValueNotifier<bool>(false);
  static bool get lite => liteNotifier.value;
  static set lite(bool v) => liteNotifier.value = v;
}

/// Palette de l'appli, selon le thème choisi ([skin]). Les noms « gold… »
/// désignent la couleur d'accent du thème (or dans le thème d'origine).
class Tv {
  /// Thème choisi pour l'appli ; l'appli se redessine quand il change.
  static final skin = ValueNotifier<AppSkin>(AppSkin.gold);

  /// Thème du jeu en cours (réglages du jeu, partie, écran TV) : passe
  /// avant [skin] tant qu'il est posé (voir game_theme.dart).
  static final game = ValueNotifier<AppSkin?>(null);

  /// Thème affiché : celui du jeu, sinon celui de l'appli.
  static AppSkin get current => game.value ?? skin.value;

  /// L'un ou l'autre change : l'appli se redessine.
  static final changes = Listenable.merge([skin, game]);

  static const prefKey = 'app_skin';

  static AppSkin get _s => current;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      skin.value = AppSkin.byId(p.getString(prefKey));
    } catch (_) {}
  }

  static Future<void> choose(AppSkin s) async {
    skin.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(prefKey, s.id);
    } catch (_) {}
  }

  /// À passer à `MaterialApp.builder` : fond animé derrière toutes les pages.
  static Widget appBuilder(BuildContext context, Widget? child) =>
      SkinBackground(child: child ?? const SizedBox.shrink());

  static Color get bg => _s.bg;
  static Color get panel => _s.panel;
  static Color get panel2 => _s.panel2;
  static Color get line => _s.line;
  static Color get gold => _s.accent;
  static Color get goldLight => _s.accentLight;
  static Color get goldDark => _s.accentDark;
  static Color get muted => _s.muted;
  static const red = Color(0xFFD7262F);
  static const green = Color(0xFF1AA155);
  static const cream = Color(0xFFEEE2C4);
  static const text = Color(0xFFF4F4F6);
  static const ice = Color(0xFF7FD3FF);

  static const font = 'Barlow';

  static LinearGradient get goldGradient => LinearGradient(
        colors: [goldLight, gold, goldDark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get panelGradient => LinearGradient(
        colors: _s.panelColors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static TextStyle title(double size, {Color color = text}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.0,
        letterSpacing: 0.5,
      );

  static TextStyle label(double size, {Color? color}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? muted,
        letterSpacing: 1.2,
      );

  static ThemeData theme() {
    final scheme = ColorScheme.dark(
      primary: gold,
      onPrimary: Colors.black,
      primaryContainer: Color.lerp(goldDark, bg, 0.6)!,
      onPrimaryContainer: goldLight,
      secondary: green,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF0E3A22),
      onSecondaryContainer: Colors.white,
      error: red,
      errorContainer: const Color(0xFF4A0E12),
      surface: panel,
      onSurface: text,
      surfaceContainer: panel,
      surfaceContainerHigh: panel2,
      surfaceContainerHighest: line,
      outline: muted,
      outlineVariant: line,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: font,
      // Transparent : le fond animé du thème est derrière toutes les pages
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: panel,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: font,
        bodyColor: text,
        displayColor: text,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _FadePageTransition(),
        TargetPlatform.iOS: _FadePageTransition(),
        TargetPlatform.linux: _FadePageTransition(),
        TargetPlatform.macOS: _FadePageTransition(),
        TargetPlatform.windows: _FadePageTransition(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: title(24, color: gold).copyWith(letterSpacing: 1.5),
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          textStyle: title(18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: line, width: 1.5),
          textStyle: title(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: panel2,
        selectedColor: gold,
        side: BorderSide(color: line),
        labelStyle: title(16),
        secondaryLabelStyle: title(16, color: Colors.black),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(title(15)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? gold : panel2),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.black : text),
          side: WidgetStatePropertyAll(BorderSide(color: line)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.black : muted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? gold : panel2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel2,
        contentTextStyle: title(16),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: line,
    );
  }
}

/// Fenêtre qui monte du bas : poignée pour la faire glisser + petite croix
/// pour la fermer, jusqu'à presque toute la hauteur (paysage).
Future<T?> showAppSheet<T>(BuildContext context,
        {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tv.panel,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.94, maxWidth: 900),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Tv.muted,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    key: const ValueKey('sheet-close'),
                    tooltip: 'Fermer',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).maybePop(),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: builder(ctx)),
        ],
      ),
    );

/// Titre de section façon bandeau TV (barre or à gauche).
class TvSection extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const TvSection(this.text,
      {super.key, this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: Tv.gold, boxShadow: [
              BoxShadow(color: Tv.gold.withValues(alpha: 0.6), blurRadius: 8)
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.label(15, color: Tv.gold)),
          ),
        ],
      ),
    );
  }
}

/// Les pages sont transparentes (fond animé commun) : fondu enchaîné
/// plutôt qu'un glissement, où l'ancienne page se verrait à travers.
class _FadePageTransition extends PageTransitionsBuilder {
  const _FadePageTransition();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      FadeTransition(
        opacity:
            CurvedAnimation(parent: animation, curve: const Interval(0.35, 1)),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
              parent: secondaryAnimation, curve: const Interval(0, 0.5))),
          child: child,
        ),
      );
}

/// Ancien fond de page : le fond du thème est maintenant posé une fois pour
/// toute l'appli par [SkinBackground] (voir `main.dart`).
class TvBackground extends StatelessWidget {
  final Widget child;
  const TvBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Fond animé du thème, derrière toutes les pages : lueurs qui dérivent +
/// motif du thème (projecteurs, grille néon, pétales, braises).
class SkinBackground extends StatefulWidget {
  final Widget child;
  const SkinBackground({super.key, required this.child});

  /// Faux en test : fond fixe (sinon `pumpAndSettle` ne finirait jamais).
  static bool animate = true;

  @override
  State<SkinBackground> createState() => _SkinBackgroundState();
}

class _SkinBackgroundState extends State<SkinBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void initState() {
    super.initState();
    // Écran TV : fond fixe (redessiné seulement s'il change)
    _applyPerf();
    Perf.liteNotifier.addListener(_applyPerf);
  }

  void _applyPerf() {
    if (Perf.lite) {
      _c.stop();
      _c.value = 0.15;
    } else if (SkinBackground.animate && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    Perf.liteNotifier.removeListener(_applyPerf);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = Tv.current;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: skin.fx == SkinFx.wallpaper
              ? _WallpaperBackground(controller: _c)
              : CustomPaint(painter: _SkinPainter(skin, _c), isComplex: true),
        ),
        widget.child,
      ],
    );
  }
}

/// Fond d'écran : l'image choisie, qui zoome très lentement, assombrie
/// (plus en bas, où sont les boutons) pour garder le texte lisible.
class _WallpaperBackground extends StatelessWidget {
  final AnimationController controller;
  const _WallpaperBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: ListenableBuilder(
        listenable: Wallpaper.instance,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) => Transform.scale(
                scale: 1.04 + 0.04 * math.sin(controller.value * 2 * math.pi),
                child: child,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Image(
                  key: ValueKey(Wallpaper.instance.shown),
                  image: Wallpaper.instance.current,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.expand(),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Color(0xB3000000),
                    Color(0xD9000000)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinPainter extends CustomPainter {
  final AppSkin skin;
  final Animation<double> t;
  _SkinPainter(this.skin, this.t) : super(repaint: t);

  // Valeur pseudo-aléatoire stable pour l'élément [i]
  double _r(int i, int k) =>
      ((math.sin(i * 127.1 + k * 311.7) * 43758.5453) % 1).abs();

  void _glow(
      Canvas c, Size s, Offset at, double radius, Color color, double alpha) {
    final rect = Rect.fromCircle(center: at, radius: radius);
    c.drawCircle(
        at,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]).createShader(rect));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = t.value * 2 * math.pi;
    canvas.drawRect(Offset.zero & size, Paint()..color = skin.bg);
    // Deux lueurs qui dérivent lentement
    _glow(canvas, size, Offset(w * (0.25 + 0.2 * math.sin(a)), h * -0.05),
        w * 0.55, skin.accent, 0.20);
    _glow(
        canvas,
        size,
        Offset(w * (0.8 + 0.15 * math.cos(a * 2)),
            h * (1.05 + 0.1 * math.sin(a * 3))),
        w * 0.5,
        skin.glow,
        0.16);
    switch (skin.fx) {
      case SkinFx.wallpaper:
        break;
      case SkinFx.spotlight:
        // Faisceaux de projecteurs qui balaient depuis le haut
        for (var i = 0; i < 3; i++) {
          final x = w * (0.2 + 0.3 * i);
          final ang = 0.35 * math.sin(a * (i + 1) + i * 2.1);
          final path = Path()
            ..moveTo(x - 6, -10)
            ..lineTo(x + 6, -10)
            ..lineTo(x + h * 1.2 * math.tan(ang) + w * 0.09, h * 1.1)
            ..lineTo(x + h * 1.2 * math.tan(ang) - w * 0.09, h * 1.1)
            ..close();
          canvas.drawPath(
              path,
              Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    skin.accentLight.withValues(alpha: 0.10),
                    skin.accentLight.withValues(alpha: 0),
                  ],
                ).createShader(Offset.zero & size));
        }
      case SkinFx.grid:
        // Sol en perspective qui avance + horizon lumineux
        final horizon = h * 0.42;
        final line = Paint()
          ..color = skin.accent.withValues(alpha: 0.16)
          ..strokeWidth = 1;
        for (var i = -12; i <= 12; i++) {
          canvas.drawLine(Offset(w / 2 + i * w * 0.02, horizon),
              Offset(w / 2 + i * w * 0.16, h), line);
        }
        final shift = (t.value * 12) % 1;
        for (var i = 0; i < 9; i++) {
          final z = (i + shift) / 9;
          final y = horizon + (h - horizon) * z * z;
          canvas.drawLine(
              Offset(0, y),
              Offset(w, y),
              Paint()
                ..color = skin.glow.withValues(alpha: 0.05 + 0.16 * z)
                ..strokeWidth = 1);
        }
        canvas.drawRect(
            Rect.fromLTWH(0, horizon - 1, w, 2),
            Paint()
              ..shader = LinearGradient(colors: [
                skin.glow.withValues(alpha: 0),
                skin.glow.withValues(alpha: 0.5),
                skin.glow.withValues(alpha: 0),
              ]).createShader(Rect.fromLTWH(0, horizon - 1, w, 2)));
      case SkinFx.petals:
        // Pétales qui tombent en tournant
        for (var i = 0; i < 26; i++) {
          final speed = 1 + (i % 3);
          final y = ((_r(i, 1) + t.value * speed) % 1) * (h + 40) - 20;
          final x = _r(i, 2) * w + 30 * math.sin(a * speed + i);
          final sz = 5 + 9 * _r(i, 3);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(a * speed * 2 + i);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset.zero, width: sz, height: sz * 0.55),
              Paint()
                ..color = (i.isEven ? skin.accentLight : skin.accent)
                    .withValues(alpha: 0.10 + 0.22 * _r(i, 4)));
          canvas.restore();
        }
      case SkinFx.embers:
        // Braises qui montent en vacillant
        for (var i = 0; i < 34; i++) {
          final speed = 1 + (i % 4);
          final p = (_r(i, 1) + t.value * speed) % 1;
          final y = h + 10 - p * (h + 20);
          final x = _r(i, 2) * w + 18 * math.sin(a * speed * 2 + i);
          final sz = 1.2 + 2.6 * _r(i, 3);
          canvas.drawCircle(
              Offset(x, y),
              sz,
              Paint()
                ..color = (i % 3 == 0 ? skin.accentLight : skin.accent)
                    .withValues(alpha: (1 - p) * (0.25 + 0.5 * _r(i, 4)))
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        }
      case SkinFx.snow:
        // Flocons qui tombent en dérivant (les gros plus vite, plus flous)
        for (var i = 0; i < 46; i++) {
          final depth = _r(i, 3);
          final speed = 0.6 + depth * 1.8;
          final y = ((_r(i, 1) + t.value * speed * 2) % 1) * (h + 20) - 10;
          final x = (_r(i, 2) * w + 26 * math.sin(a * 3 + i)) % w;
          canvas.drawCircle(
              Offset(x, y),
              1 + 2.6 * depth,
              Paint()
                ..color = skin.accentLight
                    .withValues(alpha: 0.15 + 0.4 * (1 - depth * 0.5))
                ..maskFilter =
                    MaskFilter.blur(BlurStyle.normal, 0.5 + 1.5 * depth));
        }
      case SkinFx.bokeh:
        // Lumières de bar floues qui flottent et respirent
        for (var i = 0; i < 16; i++) {
          final x = w * _r(i, 1) + 40 * math.sin(a + i * 1.7);
          final y = h * _r(i, 2) + 30 * math.cos(a * 1.3 + i);
          final rad = w * (0.03 + 0.06 * _r(i, 3));
          final pulse = 0.5 + 0.5 * math.sin(a * 2 + i * 2.3);
          final c = switch (i % 3) {
            0 => skin.accent,
            1 => skin.glow,
            _ => skin.accentLight,
          };
          canvas.drawCircle(
              Offset(x, y),
              rad,
              Paint()
                ..color = c.withValues(alpha: 0.05 + 0.09 * pulse)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.25));
        }
      case SkinFx.sunset:
        // Soleil rayé sur l'horizon + sol quadrillé qui avance
        final horizon = h * 0.58;
        final sunR = h * 0.28;
        final sun =
            Rect.fromCircle(center: Offset(w / 2, horizon), radius: sunR);
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, 0, w, horizon));
        canvas.drawCircle(
            sun.center,
            sunR,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  skin.glow.withValues(alpha: 0.55),
                  skin.accent.withValues(alpha: 0.45),
                ],
              ).createShader(sun));
        // bandes qui défilent dans le bas du soleil (dans le soleil seulement)
        canvas.clipPath(Path()..addOval(sun));
        final band = (t.value * 8) % 1;
        for (var i = 0; i < 6; i++) {
          final y = horizon - sunR * 0.55 + (i + band) * sunR * 0.1;
          canvas.drawRect(Rect.fromLTRB(0, y, w, y + 2.0 + i * 1.4),
              Paint()..color = skin.bg);
        }
        canvas.restore();
        final gl = Paint()
          ..color = skin.accent.withValues(alpha: 0.22)
          ..strokeWidth = 1;
        for (var i = -14; i <= 14; i++) {
          canvas.drawLine(Offset(w / 2 + i * w * 0.02, horizon),
              Offset(w / 2 + i * w * 0.18, h), gl);
        }
        final shift = (t.value * 14) % 1;
        for (var i = 0; i < 8; i++) {
          final z = (i + shift) / 8;
          final y = horizon + (h - horizon) * z * z;
          canvas.drawLine(
              Offset(0, y),
              Offset(w, y),
              Paint()
                ..color = skin.accent.withValues(alpha: 0.06 + 0.2 * z)
                ..strokeWidth = 1);
        }
      case SkinFx.bubbles:
        // Bulles qui remontent en ondulant + rais de lumière
        for (var i = 0; i < 3; i++) {
          final x = w * (0.2 + 0.32 * i) + 30 * math.sin(a + i);
          canvas.drawPath(
              Path()
                ..moveTo(x - w * 0.03, 0)
                ..lineTo(x + w * 0.03, 0)
                ..lineTo(x + w * 0.12, h)
                ..lineTo(x - w * 0.02, h)
                ..close(),
              Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    skin.accentLight.withValues(alpha: 0.07),
                    skin.accentLight.withValues(alpha: 0),
                  ],
                ).createShader(Offset.zero & size));
        }
        for (var i = 0; i < 30; i++) {
          final speed = 1 + (i % 3);
          final p = (_r(i, 1) + t.value * speed * 1.5) % 1;
          final y = h + 12 - p * (h + 24);
          final x = _r(i, 2) * w + 14 * math.sin(a * speed * 3 + i);
          final rad = 2 + 6 * _r(i, 3);
          canvas.drawCircle(
              Offset(x, y),
              rad,
              Paint()
                ..color = skin.accentLight.withValues(alpha: 0.10 + 0.2 * p)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2);
          canvas.drawCircle(Offset(x - rad * 0.35, y - rad * 0.35), rad * 0.22,
              Paint()..color = Colors.white.withValues(alpha: 0.15 + 0.2 * p));
        }
      case SkinFx.stars:
        // Étoiles qui scintillent + étoile filante de temps en temps
        for (var i = 0; i < 90; i++) {
          final tw = 0.5 + 0.5 * math.sin(a * (2 + i % 5) + i * 1.3);
          final x = _r(i, 1) * w + 6 * math.sin(a + i);
          final y = _r(i, 2) * h;
          canvas.drawCircle(
              Offset(x, y),
              0.6 + 1.4 * _r(i, 3),
              Paint()
                ..color = (i % 7 == 0 ? skin.accentLight : Colors.white)
                    .withValues(alpha: 0.15 + 0.6 * tw * _r(i, 4)));
        }
        final fall = (t.value * 5) % 1;
        if (fall < 0.18) {
          final q = fall / 0.18;
          final start = Offset(
              w * (0.15 + 0.5 * ((t.value * 5).floor() % 3) / 3), h * 0.08);
          final head = start + Offset(w * 0.35, h * 0.3) * q;
          canvas.drawLine(
              head - Offset(w * 0.08, h * 0.07),
              head,
              Paint()
                ..shader = LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.8 * (1 - q)),
                ]).createShader(
                    Rect.fromPoints(head - Offset(w * 0.08, h * 0.07), head))
                ..strokeWidth = 2
                ..strokeCap = StrokeCap.round);
        }
      case SkinFx.carbon:
        // Trame fibre de carbone + reflet qui balaie en diagonale
        const step = 14.0;
        final weave = Paint()..color = Colors.white.withValues(alpha: 0.025);
        for (var y = 0.0; y < h; y += step) {
          for (var x = ((y / step).floor().isEven ? 0.0 : step);
              x < w;
              x += step * 2) {
            canvas.drawRect(Rect.fromLTWH(x, y, step, step * 0.5), weave);
          }
        }
        final sweep = ((t.value * 3) % 1) * (w + h) * 1.4 - h;
        canvas.drawPath(
            Path()
              ..moveTo(sweep, 0)
              ..lineTo(sweep + w * 0.12, 0)
              ..lineTo(sweep + w * 0.12 - h, h)
              ..lineTo(sweep - h, h)
              ..close(),
            Paint()
              ..color = skin.accentLight.withValues(alpha: 0.05)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
      case SkinFx.arena:
        // 01 : anneaux d'une cible géante qui tournent lentement + faisceaux
        final c0 = Offset(w * 0.5, h * 1.15);
        for (var i = 0; i < 7; i++) {
          final rr = h * (0.35 + i * 0.22);
          canvas.drawCircle(
              c0,
              rr,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = i.isEven ? 10 : 2
                ..color = (i.isEven ? skin.accent : skin.glow)
                    .withValues(alpha: i.isEven ? 0.06 : 0.12));
        }
        for (var i = 0; i < 20; i++) {
          final ang = a * 0.5 + i * math.pi / 10;
          canvas.drawLine(
              c0 + Offset(math.cos(ang), math.sin(ang)) * h * 0.3,
              c0 + Offset(math.cos(ang), math.sin(ang)) * h * 1.7,
              Paint()
                ..color = skin.accentLight.withValues(alpha: 0.05)
                ..strokeWidth = 1);
        }
        for (final x in [0.12, 0.88]) {
          final sway = 0.25 * math.sin(a * 2 + x * 9);
          canvas.drawPath(
              Path()
                ..moveTo(w * x - 5, -10)
                ..lineTo(w * x + 5, -10)
                ..lineTo(w * (0.5 + sway) + w * 0.08, h)
                ..lineTo(w * (0.5 + sway) - w * 0.08, h)
                ..close(),
              Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    skin.accentLight.withValues(alpha: 0.09),
                    skin.accentLight.withValues(alpha: 0),
                  ],
                ).createShader(Offset.zero & size));
        }
      case SkinFx.chalk:
        // Cricket : tableau noir, marques à la craie ( / X ⊗ ) qui dérivent
        final chalk = Paint()
          ..color = skin.accentLight.withValues(alpha: 0.10)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < 22; i++) {
          final x = (_r(i, 1) * w + t.value * w * (0.3 + _r(i, 5) * 0.4)) %
              (w + 40) -
              20;
          final y = _r(i, 2) * h;
          final s = 9 + 9 * _r(i, 3);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate((_r(i, 4) - 0.5) * 0.6);
          canvas.drawLine(Offset(-s, s), Offset(s, -s), chalk);
          if (i % 3 != 0) canvas.drawLine(Offset(-s, -s), Offset(s, s), chalk);
          if (i % 3 == 2) canvas.drawCircle(Offset.zero, s * 1.25, chalk);
          canvas.restore();
        }
        // traînées de craie effacée
        for (var i = 0; i < 4; i++) {
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(w * _r(i, 7), h * _r(i, 8)),
                  width: w * 0.4,
                  height: h * 0.12),
              Paint()
                ..color = Colors.white.withValues(alpha: 0.025)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
        }
      case SkinFx.duel:
        // Medley : deux camps de couleur séparés par une diagonale qui ondule
        final mid = w * (0.5 + 0.06 * math.sin(a * 2));
        final left = Path()
          ..moveTo(0, 0)
          ..lineTo(mid + w * 0.12, 0)
          ..lineTo(mid - w * 0.12, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(left, Paint()..color = skin.glow.withValues(alpha: 0.10));
        canvas.drawPath(
            Path()
              ..moveTo(mid + w * 0.12, 0)
              ..lineTo(w, 0)
              ..lineTo(w, h)
              ..lineTo(mid - w * 0.12, h)
              ..close(),
            Paint()..color = skin.accent.withValues(alpha: 0.08));
        canvas.drawLine(
            Offset(mid + w * 0.12, 0),
            Offset(mid - w * 0.12, h),
            Paint()
              ..color = skin.accentLight.withValues(alpha: 0.35)
              ..strokeWidth = 2
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        for (var i = 0; i < 18; i++) {
          final p = (_r(i, 1) + t.value * 3) % 1;
          final y = p * h;
          final x = mid + w * 0.12 - (mid + w * 0.12 - (mid - w * 0.12)) * p +
              (i.isEven ? -1 : 1) * (8 + 30 * _r(i, 2));
          canvas.drawCircle(Offset(x, y), 1.5,
              Paint()..color = skin.accentLight.withValues(alpha: 0.4));
        }
      case SkinFx.hud:
        // Entraînement : viseur, cercles de mire et balayage radar
        final cc = Offset(w * 0.72, h * 0.5);
        final hud = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = skin.accent.withValues(alpha: 0.16);
        for (var i = 1; i <= 5; i++) {
          canvas.drawCircle(cc, h * 0.12 * i, hud);
        }
        canvas.drawLine(Offset(cc.dx, 0), Offset(cc.dx, h), hud);
        canvas.drawLine(Offset(0, cc.dy), Offset(w, cc.dy), hud);
        final sweepA = a * 3;
        canvas.drawArc(
            Rect.fromCircle(center: cc, radius: h * 0.6),
            sweepA,
            0.6,
            true,
            Paint()
              ..shader = SweepGradient(
                startAngle: sweepA,
                endAngle: sweepA + 0.6,
                colors: [
                  skin.accent.withValues(alpha: 0),
                  skin.accent.withValues(alpha: 0.16),
                ],
              ).createShader(Rect.fromCircle(center: cc, radius: h * 0.6)));
        final grid = Paint()..color = skin.accent.withValues(alpha: 0.04);
        for (var x = 0.0; x < w; x += 40) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
        }
        for (var y = 0.0; y < h; y += 40) {
          canvas.drawLine(Offset(0, y), Offset(w, y), grid);
        }
      case SkinFx.confetti:
        // Party : confettis de toutes les couleurs qui tombent en tournant
        const colors = [
          Color(0xFFFF4FB4), Color(0xFFFFD23F), Color(0xFF3EE8B5), //
          Color(0xFF5B8CFF), Color(0xFFFF7A3D),
        ];
        for (var i = 0; i < 40; i++) {
          final speed = 1 + (i % 3);
          final y = ((_r(i, 1) + t.value * speed * 1.5) % 1) * (h + 30) - 15;
          final x = _r(i, 2) * w + 24 * math.sin(a * speed * 2 + i);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(a * speed * 4 + i);
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: 7,
                  height: 3 + 4 * (0.5 + 0.5 * math.sin(a * 8 + i))),
              Paint()
                ..color = colors[i % colors.length]
                    .withValues(alpha: 0.25 + 0.3 * _r(i, 3)));
          canvas.restore();
        }
      case SkinFx.lanes:
        // Bowling : pistes en bois en perspective, flèches et néons
        final vy = h * 0.18;
        final wood = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8A5A2B).withValues(alpha: 0.05),
              const Color(0xFFC8955A).withValues(alpha: 0.22),
            ],
          ).createShader(Offset.zero & size);
        for (var i = -1; i <= 1; i++) {
          final cx = w / 2 + i * w * 0.36;
          canvas.drawPath(
              Path()
                ..moveTo(w / 2 + i * w * 0.08 - w * 0.035, vy)
                ..lineTo(w / 2 + i * w * 0.08 + w * 0.035, vy)
                ..lineTo(cx + w * 0.15, h)
                ..lineTo(cx - w * 0.15, h)
                ..close(),
              wood);
          for (var k = -2; k <= 2; k++) {
            const z = 0.72;
            final ax = (w / 2 + i * w * 0.08) +
                ((cx + k * w * 0.03) - (w / 2 + i * w * 0.08)) * z;
            final ay = vy + (h - vy) * z;
            canvas.drawPath(
                Path()
                  ..moveTo(ax, ay - 10)
                  ..lineTo(ax + 5, ay)
                  ..lineTo(ax - 5, ay)
                  ..close(),
                Paint()..color = skin.glow.withValues(alpha: 0.25));
          }
        }
        // néons du fond qui clignotent doucement
        final blink = 0.5 + 0.5 * math.sin(a * 6);
        canvas.drawRect(
            Rect.fromLTWH(0, vy - 6, w, 4),
            Paint()
              ..color = skin.accent.withValues(alpha: 0.25 + 0.3 * blink)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        for (var i = 0; i < 10; i++) {
          canvas.drawCircle(
              Offset(w * (0.05 + i * 0.1), vy - 18),
              3,
              Paint()
                ..color = (i.isEven ? skin.accent : skin.glow)
                    .withValues(alpha: 0.3 + 0.4 * ((blink + i * 0.1) % 1)));
        }
      case SkinFx.fairway:
        // Golf : collines vertes, drapeau qui flotte, nuages qui passent
        for (var i = 0; i < 3; i++) {
          final base = h * (0.55 + i * 0.13);
          final hill = Path()..moveTo(0, h);
          for (var x = 0.0; x <= w + 20; x += 20) {
            hill.lineTo(
                x,
                base +
                    h * 0.05 * math.sin(x / w * math.pi * (2 + i) + i * 1.3 + a * 0.3));
          }
          hill
            ..lineTo(w, h)
            ..close();
          canvas.drawPath(
              hill,
              Paint()
                ..color = Color.lerp(skin.accentDark, skin.accent, i / 3)!
                    .withValues(alpha: 0.18 + i * 0.06));
        }
        final fx0 = w * 0.78, fy0 = h * 0.6;
        canvas.drawLine(Offset(fx0, fy0), Offset(fx0, fy0 - h * 0.22),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.4)
              ..strokeWidth = 2);
        final wave = math.sin(a * 6) * 6;
        canvas.drawPath(
            Path()
              ..moveTo(fx0, fy0 - h * 0.22)
              ..quadraticBezierTo(fx0 + 22, fy0 - h * 0.22 + 6 + wave,
                  fx0 + 44, fy0 - h * 0.2 + wave)
              ..lineTo(fx0, fy0 - h * 0.15)
              ..close(),
            Paint()..color = skin.glow.withValues(alpha: 0.6));
        for (var i = 0; i < 4; i++) {
          final x = ((_r(i, 1) + t.value * (0.5 + i * 0.2)) % 1.3) * w * 1.1 - w * 0.2;
          final y = h * (0.08 + 0.12 * _r(i, 2));
          for (var k = 0; k < 3; k++) {
            canvas.drawCircle(
                Offset(x + k * 26, y + (k == 1 ? -8 : 0)),
                18 + 6 * (k == 1 ? 1 : 0),
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.05)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          }
        }
      case SkinFx.pitch:
        // Football : pelouse rayée, lignes du terrain, ballon qui roule
        const stripes = 10;
        for (var i = 0; i < stripes; i++) {
          if (i.isEven) {
            canvas.drawRect(Rect.fromLTWH(w * i / stripes, 0, w / stripes, h),
                Paint()..color = Colors.white.withValues(alpha: 0.025));
          }
        }
        final line = Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.06, w * 0.92, h * 0.88), line);
        canvas.drawLine(Offset(w / 2, h * 0.06), Offset(w / 2, h * 0.94), line);
        canvas.drawCircle(Offset(w / 2, h / 2), h * 0.16, line);
        canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.3, w * 0.1, h * 0.4), line);
        canvas.drawRect(Rect.fromLTWH(w * 0.86, h * 0.3, w * 0.1, h * 0.4), line);
        final bx = w * (0.1 + 0.8 * (0.5 + 0.5 * math.sin(a)));
        final by = h * (0.5 + 0.3 * math.sin(a * 2));
        canvas.drawCircle(Offset(bx, by), 9,
            Paint()..color = Colors.white.withValues(alpha: 0.25));
        canvas.drawCircle(Offset(bx, by), 3.5,
            Paint()..color = Colors.black.withValues(alpha: 0.25));
      case SkinFx.paws:
        // Le Chat et la Souris : empreintes de pattes qui traversent l'écran
        final paw = Paint()..color = skin.accentLight.withValues(alpha: 0.10);
        final small = Paint()..color = skin.glow.withValues(alpha: 0.12);
        for (var track = 0; track < 2; track++) {
          final y0 = h * (track == 0 ? 0.3 : 0.75);
          final steps = track == 0 ? 9 : 14;
          final head = (t.value * 4 + track * 0.5) % 1;
          for (var i = 0; i < steps; i++) {
            final p = i / steps;
            if (p > head) continue;
            final fade = 1 - (head - p) * 1.4;
            if (fade <= 0) continue;
            final x = p * (w + 60) - 30;
            final y = y0 + (i.isEven ? -10.0 : 10.0) + 20 * math.sin(p * 6);
            final s = track == 0 ? 1.0 : 0.55;
            final pp = track == 0 ? paw : small;
            final alpha = pp.color.a * fade;
            final q = Paint()..color = pp.color.withValues(alpha: alpha);
            canvas.drawOval(
                Rect.fromCenter(center: Offset(x, y), width: 14 * s, height: 12 * s), q);
            for (var k = 0; k < 4; k++) {
              final ang = -0.9 + k * 0.6;
              canvas.drawCircle(
                  Offset(x + math.sin(ang) * 11 * s + 6 * s, y - math.cos(ang) * 11 * s),
                  3 * s,
                  q);
            }
          }
        }
      case SkinFx.splats:
        // Paint : taches de peinture qui apparaissent et s'effacent
        const colors = [
          Color(0xFFFF4FB4), Color(0xFF3EE8B5), Color(0xFFFFD23F), //
          Color(0xFF5B8CFF), Color(0xFFFF5E3A),
        ];
        for (var i = 0; i < 12; i++) {
          final life = (_r(i, 1) + t.value * 3) % 1;
          final grow = math.min(1.0, life * 5);
          final alpha = life < 0.7 ? 0.2 : 0.2 * (1 - (life - 0.7) / 0.3);
          final c = colors[i % colors.length].withValues(alpha: alpha);
          final cc = Offset(w * _r(i, 2), h * _r(i, 3));
          final rr = (20 + 40 * _r(i, 4)) * grow;
          final pt = Paint()..color = c;
          canvas.drawCircle(cc, rr, pt);
          for (var k = 0; k < 6; k++) {
            final ang = k * 1.05 + i;
            canvas.drawCircle(
                cc + Offset(math.cos(ang), math.sin(ang)) * rr * (1.2 + 0.4 * _r(i, k + 5)),
                rr * 0.18,
                pt);
          }
        }
      case SkinFx.clock:
        // Contre la montre : grand cadran, trotteuse qui tourne, damier
        final cc = Offset(w * 0.5, h * 0.5);
        final rr = h * 0.42;
        final dial = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = skin.accent.withValues(alpha: 0.14);
        canvas.drawCircle(cc, rr, dial);
        for (var i = 0; i < 60; i++) {
          final ang = i * math.pi / 30;
          final len = i % 5 == 0 ? 16.0 : 6.0;
          canvas.drawLine(
              cc + Offset(math.cos(ang), math.sin(ang)) * (rr - len),
              cc + Offset(math.cos(ang), math.sin(ang)) * rr,
              Paint()
                ..color = skin.accentLight.withValues(alpha: i % 5 == 0 ? 0.22 : 0.1)
                ..strokeWidth = i % 5 == 0 ? 3 : 1.5);
        }
        final hand = a * 10 - math.pi / 2;
        canvas.drawLine(
            cc,
            cc + Offset(math.cos(hand), math.sin(hand)) * rr * 0.92,
            Paint()
              ..color = skin.glow.withValues(alpha: 0.35)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round);
        const sq = 18.0;
        for (var x = 0.0; x < w; x += sq) {
          if ((x / sq).floor().isEven) {
            canvas.drawRect(Rect.fromLTWH(x, h - sq * 2, sq, sq),
                Paint()..color = Colors.white.withValues(alpha: 0.04));
          } else {
            canvas.drawRect(Rect.fromLTWH(x, h - sq, sq, sq),
                Paint()..color = Colors.white.withValues(alpha: 0.04));
          }
        }
    }
    // Bords assombris : le contenu reste lisible
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            radius: 0.95,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
            stops: const [0.55, 1],
          ).createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(_SkinPainter old) => old.skin != skin;
}
