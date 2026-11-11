import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio.dart';
import '../board_service.dart';
import '../game/practice.dart';
import '../players.dart';
import '../tv_link.dart';
import '../update_check.dart';
import 'calibration_page.dart';
import 'connect_page.dart';
import 'dartboard.dart';
import 'diagnostic_page.dart';
import 'players_page.dart';
import 'ranking_page.dart';
import 'setup_page.dart';
import 'sound_settings.dart';
import 'theme.dart';
import 'tv_sheet.dart';
import 'welcome_page.dart';
import 'widgets.dart';

/// Accueil en grille : une tuile par famille de jeux (la grande tuile 01
/// rappelle le dernier score de départ), la cible, l'écran TV, les
/// classements et le joueur en haut.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final board = BoardService.instance;
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 90))
        ..repeat();
  int _start = 501;

  static final _practiceCount =
      kPracticeInfo.values.where((i) => !i.party).length;
  static final _partyCount = kPracticeInfo.values.where((i) => i.party).length;

  @override
  void initState() {
    super.initState();
    AudioService.instance.startMusic();
    TvLink.instance.pushLobby();
    _loadStart();
    // Premier lancement : profil principal
    final store = PlayerStore.instance;
    if (!store.welcomed && store.players.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true, builder: (_) => const WelcomePage()));
        }
      });
    }
    // Reconnexion automatique à la dernière cible
    if (board.lastId != null && !board.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => board.reconnect());
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// Dernier score de départ choisi (affiché sur la grande tuile).
  Future<void> _loadStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kSetupPrefKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final v = (j['start'] as num?)?.toInt();
      if (v != null && mounted) setState(() => _start = v);
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    final r = await updateGateKey.currentState?.check(manual: true);
    if (!mounted || r == 1) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r == 2
            ? 'Impossible de joindre GitHub'
            : 'À jour (v$kAppVersion)')));
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    AudioService.instance.startMusic();
    TvLink.instance.pushLobby();
    _loadStart();
  }

  Future<void> _chooseSkin() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Tv.panel,
        showDragHandle: true,
        builder: (ctx) => ValueListenableBuilder<BoardSkin>(
          valueListenable: BoardSkin.current,
          builder: (ctx, cur, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TvSection('Style de la cible',
                    padding: EdgeInsets.only(bottom: 10)),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final sk in BoardSkin.all)
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          BoardSkin.choose(sk);
                          TvLink.instance.pushLobby();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: cur == sk ? Tv.gold : Tv.line,
                                width: cur == sk ? 2.5 : 1),
                          ),
                          child: Column(
                            children: [
                              DartboardPreview(skin: sk, size: 120),
                              const SizedBox(height: 6),
                              Text(sk.name.toUpperCase(),
                                  style: Tv.title(18,
                                      color:
                                          cur == sk ? Tv.goldLight : Tv.text)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('S\'applique partout, écran TV compris.',
                    style: Tv.label(12)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TvBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 10),
            child: Column(
              children: [
                // ─── Barre du haut ───
                SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      Flexible(
                        flex: 0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ShaderMask(
                            shaderCallback: (r) =>
                                Tv.goldGradient.createShader(r),
                            child: Text('GRANBOARD',
                                style: Tv.title(30, color: Colors.white)
                                    .copyWith(letterSpacing: 2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 3,
                        child: ListenableBuilder(
                          listenable: board,
                          builder: (context, _) => _BoardPill(
                            board: board,
                            onChoose: () => _open(const ConnectPage()),
                            onDiagnostic: () => _open(const DiagnosticPage()),
                            onCalibrate: () => _open(const CalibrationPage()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ListenableBuilder(
                            listenable: PlayerStore.instance,
                            builder: (context, _) => TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Tv.text,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              onPressed: () => _open(const PlayersPage()),
                              icon: const Icon(Icons.group_add, size: 22),
                              label: Text(
                                  'JOUEURS (${PlayerStore.instance.players.length})',
                                  style: Tv.title(16)),
                            ),
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: TvLink.instance,
                        builder: (context, _) => IconButton(
                          tooltip: 'Écran TV',
                          icon: Icon(
                              TvLink.instance.linked
                                  ? Icons.connected_tv
                                  : Icons.tv,
                              color: TvLink.instance.linked ? Tv.green : null),
                          onPressed: () => showTvSheet(context),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Classements',
                        icon: const Icon(Icons.leaderboard),
                        onPressed: () => _open(const RankingPage()),
                      ),
                      IconButton(
                        tooltip: 'Sons',
                        icon: const Icon(Icons.volume_up),
                        onPressed: () => showSoundSettings(context),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Plus',
                        onSelected: (v) {
                          if (v == 'skin') _chooseSkin();
                          if (v == 'update') _checkUpdate();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'skin', child: Text('Style de la cible')),
                          const PopupMenuItem(
                              value: 'update',
                              child: Text('Mises à jour (v$kAppVersion)')),
                        ],
                      ),
                      const SizedBox(width: 4),
                      ListenableBuilder(
                        listenable: PlayerStore.instance,
                        builder: (context, _) =>
                            _MeChip(onTap: () => _open(const PlayersPage())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ─── Tuiles des jeux (3 × 2) ───
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _row([
                          _Tile(
                            colors: const [
                              Color(0xFF3A2805),
                              Color(0xFF1A1205)
                            ],
                            kicker: 'X01 · FREEZE',
                            title: '$_start',
                            gold: true,
                            spin: _spin,
                            onTap: () => _open(const SetupPage(kind: 'x01')),
                          ),
                          _Tile(
                            colors: const [
                              Color(0xFF0E3B24),
                              Color(0xFF07170F)
                            ],
                            kicker: '8 VARIANTES',
                            title: 'CRICKET',
                            icon: Icons.grid_view_rounded,
                            onTap: () =>
                                _open(const SetupPage(kind: 'cricket')),
                          ),
                          _Tile(
                            colors: const [
                              Color(0xFF3A1214),
                              Color(0xFF16080A)
                            ],
                            kicker: '01 + CRICKET',
                            title: 'MATCH',
                            icon: Icons.emoji_events,
                            onTap: () => _open(const SetupPage(kind: 'match')),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _row([
                          _Tile(
                            colors: const [
                              Color(0xFF0D2534),
                              Color(0xFF061018)
                            ],
                            kicker: '$_practiceCount JEUX',
                            title: 'ENTRAÎNEMENT',
                            icon: Icons.fitness_center,
                            onTap: () =>
                                _open(const SetupPage(kind: 'practice')),
                          ),
                          _Tile(
                            colors: const [
                              Color(0xFF2A1240),
                              Color(0xFF10071A)
                            ],
                            kicker: '$_partyCount JEUX',
                            title: 'FÊTE',
                            icon: Icons.celebration,
                            onTap: () => _open(const SetupPage(kind: 'party')),
                          ),
                          _Tile(
                            colors: const [
                              Color(0xFF1E2228),
                              Color(0xFF0C0E11)
                            ],
                            kicker: 'BIENTÔT',
                            title: 'EN LIGNE',
                            icon: Icons.public,
                            soon: true,
                            onTap: () => ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(
                                  content: Text(
                                      'Jeu en ligne : un joueur chez lui avec sa cible, bientôt !'))),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne de tuiles de même taille.
Widget _row(List<Widget> tiles) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );

/// Tuile d'une famille de jeux.
class _Tile extends StatelessWidget {
  final List<Color> colors;
  final String kicker;
  final String title;
  final IconData? icon;
  final bool gold;
  final bool soon;
  final Animation<double>? spin;
  final VoidCallback onTap;
  const _Tile(
      {required this.colors,
      required this.kicker,
      required this.title,
      required this.onTap,
      this.icon,
      this.gold = false,
      this.soon = false,
      this.spin});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: LayoutBuilder(builder: (context, c) {
            final boardSize = c.maxHeight * 0.95;
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  if (spin != null)
                    Positioned(
                      right: -boardSize * 0.22,
                      bottom: -boardSize * 0.22,
                      child: Opacity(
                        opacity: 0.55,
                        child: RotationTransition(
                          turns: spin!,
                          child: Dartboard(size: boardSize, showNumbers: true),
                        ),
                      ),
                    )
                  else if (icon != null)
                    Positioned(
                      right: -8,
                      bottom: -10,
                      child: Icon(icon,
                          size: c.maxHeight * 0.75,
                          color: Colors.white.withValues(alpha: 0.07)),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kicker,
                            style: Tv.label(12,
                                color: soon ? Tv.gold : Colors.white70)),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title,
                              style: Tv.title(38,
                                  color: gold
                                      ? Tv.goldLight
                                      : soon
                                          ? Colors.white54
                                          : Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Pastille du profil principal avec sa classe ; ouvre « Joueurs ».
class _MeChip extends StatelessWidget {
  final VoidCallback onTap;
  const _MeChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final me = PlayerStore.instance.owner;
    final rating = me?.rating;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          color: Tv.panel2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Tv.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            me == null
                ? const CircleAvatar(
                    radius: 15,
                    backgroundColor: Tv.panel,
                    child: Icon(Icons.groups, size: 18, color: Tv.text))
                : PlayerAvatar.of(me, size: 30),
            const SizedBox(width: 6),
            Text(me == null ? 'JOUEURS' : me.name.toUpperCase(),
                style: Tv.title(15)),
            if (rating != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: Tv.gold, borderRadius: BorderRadius.circular(6)),
                child: Text(ratingClass(rating),
                    style: Tv.title(13, color: Colors.black)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// État de la cible en pastille : touche = choisir une cible, menu = outils.
class _BoardPill extends StatelessWidget {
  final BoardService board;
  final VoidCallback onChoose;
  final VoidCallback onDiagnostic;
  final VoidCallback onCalibrate;
  const _BoardPill(
      {required this.board,
      required this.onChoose,
      required this.onDiagnostic,
      required this.onCalibrate});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (board.status) {
      BoardStatus.connected => (Tv.green, board.deviceName ?? 'GranBoard'),
      BoardStatus.connecting => (Tv.gold, 'Connexion…'),
      BoardStatus.disconnected => (Tv.red, 'Pas de cible'),
    };
    return Container(
      height: 36,
      constraints: const BoxConstraints(minWidth: 96),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: board.status == BoardStatus.disconnected &&
                      board.lastId != null
                  ? board.reconnect
                  : onChoose,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          '${text.toUpperCase()}${board.hasCustomTable ? ' · CALIBRÉE' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tv.title(14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cible',
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.expand_more),
            onSelected: (v) {
              if (v == 'choose') onChoose();
              if (v == 'diag') onDiagnostic();
              if (v == 'cal') onCalibrate();
              if (v == 'std') board.saveCustomTable(null);
              if (v == 'off') board.disconnect();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'choose', child: Text('Choisir une cible')),
              const PopupMenuItem(value: 'diag', child: Text('Diagnostic')),
              if (board.isConnected)
                const PopupMenuItem(
                    value: 'cal', child: Text('Calibrer cette cible')),
              if (board.hasCustomTable)
                const PopupMenuItem(
                    value: 'std', child: Text('Revenir à la table standard')),
              if (board.isConnected)
                const PopupMenuItem(value: 'off', child: Text('Déconnecter')),
            ],
          ),
        ],
      ),
    );
  }
}
