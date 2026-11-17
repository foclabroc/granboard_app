// Thème de chaque jeu : un par famille (01, Cricket, Medley, Entraînement,
// Party) et un pour les jeux phares (Bowling, Golf, Football, Le Chat et la
// Souris, Paint, Contre la montre). Imposé, dans les réglages du jeu, la
// partie et sur l'écran TV ; les menus gardent le thème de l'appli.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import 'theme.dart';

class GameSkins {
  GameSkins._();

  /// 01 : arène, rouge et or, anneaux d'une cible géante.
  static const x01 = AppSkin(
    id: 'g-x01',
    name: 'Arène',
    bg: Color(0xFF0B0507),
    panel: Color(0xFF1A0E11),
    panel2: Color(0xFF261418),
    line: Color(0xFF3A1E24),
    accent: Color(0xFFFF4B3E),
    accentLight: Color(0xFFFF8A6E),
    accentDark: Color(0xFF8E1F18),
    glow: Color(0xFFF2B33D),
    muted: Color(0xFF9C8A8E),
    panelColors: [Color(0xFF221216), Color(0xFF12080A)],
    fx: SkinFx.arena,
  );

  /// Cricket : tableau noir et craie.
  static const cricket = AppSkin(
    id: 'g-cricket',
    name: 'Ardoise',
    bg: Color(0xFF0A1410),
    panel: Color(0xFF12211B),
    panel2: Color(0xFF1A2E26),
    line: Color(0xFF2A4236),
    accent: Color(0xFF6FE39A),
    accentLight: Color(0xFFE9F3DF),
    accentDark: Color(0xFF2C7A4B),
    glow: Color(0xFFE9E1B8),
    muted: Color(0xFF8FA69A),
    panelColors: [Color(0xFF16271F), Color(0xFF0B1611)],
    fx: SkinFx.chalk,
  );

  /// Medley : duel, deux camps (bleu / rouge), accent violet.
  static const match = AppSkin(
    id: 'g-match',
    name: 'Duel',
    bg: Color(0xFF08070F),
    panel: Color(0xFF13111F),
    panel2: Color(0xFF1C192C),
    line: Color(0xFF2E2944),
    accent: Color(0xFFB58CFF),
    accentLight: Color(0xFFDCC8FF),
    accentDark: Color(0xFF5B3A9A),
    glow: Color(0xFF3D7BFF),
    muted: Color(0xFF928DA8),
    panelColors: [Color(0xFF1A1729), Color(0xFF0C0B14)],
    fx: SkinFx.duel,
  );

  /// Entraînement : viseur, mire et radar, turquoise.
  static const practice = AppSkin(
    id: 'g-practice',
    name: 'Mire',
    bg: Color(0xFF040C0E),
    panel: Color(0xFF0C1A1D),
    panel2: Color(0xFF122428),
    line: Color(0xFF1C3A40),
    accent: Color(0xFF2EE6D6),
    accentLight: Color(0xFF9CF7EE),
    accentDark: Color(0xFF167A72),
    glow: Color(0xFF2E8CE6),
    muted: Color(0xFF85A3A6),
    panelColors: [Color(0xFF102024), Color(0xFF060F11)],
    fx: SkinFx.hud,
  );

  /// Party : confettis, rose et jaune.
  static const party = AppSkin(
    id: 'g-party',
    name: 'Confettis',
    bg: Color(0xFF0E0612),
    panel: Color(0xFF1C0F22),
    panel2: Color(0xFF271530),
    line: Color(0xFF3E2249),
    accent: Color(0xFFFF4FB4),
    accentLight: Color(0xFFFF9AD6),
    accentDark: Color(0xFF9A1E66),
    glow: Color(0xFFFFD23F),
    muted: Color(0xFFA28DA8),
    panelColors: [Color(0xFF24132B), Color(0xFF110815)],
    fx: SkinFx.confetti,
  );

  /// Bowling : pistes en bois et néons.
  static const bowling = AppSkin(
    id: 'g-bowling',
    name: 'Bowling',
    bg: Color(0xFF0A0614),
    panel: Color(0xFF160F26),
    panel2: Color(0xFF201634),
    line: Color(0xFF35264F),
    accent: Color(0xFFFF3CAC),
    accentLight: Color(0xFFFF8FD0),
    accentDark: Color(0xFF8E1A5E),
    glow: Color(0xFF36D6FF),
    muted: Color(0xFF9A8EAE),
    panelColors: [Color(0xFF1C132E), Color(0xFF0D0818)],
    fx: SkinFx.lanes,
  );

  /// Golf : collines, drapeau, nuages.
  static const golf = AppSkin(
    id: 'g-golf',
    name: 'Green',
    bg: Color(0xFF06110A),
    panel: Color(0xFF0E1E13),
    panel2: Color(0xFF15291B),
    line: Color(0xFF244330),
    accent: Color(0xFF8BD650),
    accentLight: Color(0xFFD3F2A8),
    accentDark: Color(0xFF3F7A22),
    glow: Color(0xFFFF5A4E),
    muted: Color(0xFF8DA592),
    panelColors: [Color(0xFF12241A), Color(0xFF07120B)],
    fx: SkinFx.fairway,
  );

  /// Football : pelouse rayée et lignes du terrain.
  static const football = AppSkin(
    id: 'g-football',
    name: 'Stade',
    bg: Color(0xFF07140A),
    panel: Color(0xFF0E2214),
    panel2: Color(0xFF14301C),
    line: Color(0xFF224A2E),
    accent: Color(0xFFF4F7F0),
    accentLight: Color(0xFFFFFFFF),
    accentDark: Color(0xFF7FA58A),
    glow: Color(0xFF39C463),
    muted: Color(0xFF8CAA94),
    panelColors: [Color(0xFF12281A), Color(0xFF08150C)],
    fx: SkinFx.pitch,
  );

  /// Le Chat et la Souris : pattes qui traversent, orange chaleureux.
  static const catMouse = AppSkin(
    id: 'g-cat',
    name: 'Pattes',
    bg: Color(0xFF110A05),
    panel: Color(0xFF20140B),
    panel2: Color(0xFF2B1C10),
    line: Color(0xFF45301D),
    accent: Color(0xFFFF9F43),
    accentLight: Color(0xFFFFD0A0),
    accentDark: Color(0xFF8F5216),
    glow: Color(0xFFBFA6FF),
    muted: Color(0xFFA8968A),
    panelColors: [Color(0xFF26180D), Color(0xFF120B06)],
    fx: SkinFx.paws,
  );

  /// Paint : taches de peinture de toutes les couleurs.
  static const paint = AppSkin(
    id: 'g-paint',
    name: 'Atelier',
    bg: Color(0xFF0B0A0D),
    panel: Color(0xFF17151B),
    panel2: Color(0xFF211E27),
    line: Color(0xFF35303E),
    accent: Color(0xFF3EE8B5),
    accentLight: Color(0xFFA4F5DC),
    accentDark: Color(0xFF187A5D),
    glow: Color(0xFFFF4FB4),
    muted: Color(0xFF9590A0),
    panelColors: [Color(0xFF1C1A21), Color(0xFF0C0B0E)],
    fx: SkinFx.splats,
  );

  /// Contre la montre : cadran et trotteuse, jaune course.
  static const timeAttack = AppSkin(
    id: 'g-time',
    name: 'Chrono',
    bg: Color(0xFF0A0906),
    panel: Color(0xFF17150E),
    panel2: Color(0xFF211E13),
    line: Color(0xFF3A3420),
    accent: Color(0xFFFFCC00),
    accentLight: Color(0xFFFFE680),
    accentDark: Color(0xFF8C7000),
    glow: Color(0xFFFF3B30),
    muted: Color(0xFFA39C86),
    panelColors: [Color(0xFF1D1A10), Color(0xFF0C0B07)],
    fx: SkinFx.clock,
  );

  static const all = [
    x01, cricket, match, practice, party, //
    bowling, golf, football, catMouse, paint, timeAttack,
  ];

  /// Thème d'une famille de jeux ([kind] = x01 | cricket | match | practice
  /// | party) et, en entraînement / party, du jeu choisi.
  static AppSkin of(String kind, [PracticeKind? game]) {
    switch (game) {
      case PracticeKind.bowling:
        return bowling;
      case PracticeKind.golf:
        return golf;
      case PracticeKind.football:
        return football;
      case PracticeKind.catMouse:
        return catMouse;
      case PracticeKind.paint:
        return paint;
      case PracticeKind.timeAttack:
        return timeAttack;
      default:
    }
    return switch (kind) {
      'cricket' => cricket,
      'match' => match,
      'practice' => practice,
      'party' => party,
      _ => x01,
    };
  }

  /// Thème d'une partie.
  static AppSkin ofGame(DartsGame g) => switch (g) {
        CricketGame() => cricket,
        MatchGame() => match,
        PracticeGame p => of(p.settings.info.party ? 'party' : 'practice',
            p.settings.kind),
        _ => x01,
      };
}

/// Pile des thèmes de jeu posés par les écrans ouverts (réglages du jeu,
/// partie, résultats) : le dernier posé s'affiche ; plus rien = thème de
/// l'appli. Appliqué une fois par image (jamais pendant la construction).
class GameTheme {
  GameTheme._();

  static final _stack = <(Object, AppSkin)>[];
  static bool _scheduled = false;

  static void set(Object owner, AppSkin skin) {
    final i = _stack.indexWhere((e) => identical(e.$1, owner));
    if (i >= 0) {
      if (identical(_stack[i].$2, skin)) return;
      _stack[i] = (owner, skin);
    } else {
      _stack.add((owner, skin));
    }
    _apply();
  }

  static void clear(Object owner) {
    final before = _stack.length;
    _stack.removeWhere((e) => identical(e.$1, owner));
    if (_stack.length != before) _apply();
  }

  static void _apply() {
    if (_scheduled) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _now();
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _now();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  static void _now() {
    Tv.game.value = _stack.isEmpty ? null : _stack.last.$2;
  }

  /// Tests.
  static void reset() {
    _stack.clear();
    Tv.game.value = null;
  }
}

/// Pose le thème [skin] tant que ce widget est affiché.
class GameThemeScope extends StatefulWidget {
  final AppSkin skin;
  final Widget child;
  const GameThemeScope({super.key, required this.skin, required this.child});

  @override
  State<GameThemeScope> createState() => _GameThemeScopeState();
}

class _GameThemeScopeState extends State<GameThemeScope> {
  @override
  void initState() {
    super.initState();
    GameTheme.set(this, widget.skin);
  }

  @override
  void didUpdateWidget(GameThemeScope old) {
    super.didUpdateWidget(old);
    if (!identical(old.skin, widget.skin)) GameTheme.set(this, widget.skin);
  }

  @override
  void dispose() {
    GameTheme.clear(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
