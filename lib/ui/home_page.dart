import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio.dart';
import '../board_service.dart';
import '../game/practice.dart';
import '../game_save.dart';
import '../tournament.dart' show LocalTournamentStore;
import '../online/online.dart';
import '../format.dart';
import '../players.dart';
import '../server.dart';
import '../tv_link.dart';
import 'calibration_page.dart';
import 'connect_page.dart';
import 'dartboard.dart';
import 'diagnostic_page.dart';
import 'game_page.dart' show GamePage;
import 'online_page.dart';
import 'players_page.dart';
import 'ranking_page.dart';
import 'setup_page.dart';
import 'sound_settings.dart';
import 'options_page.dart';
import 'theme.dart';
import 'tile_art.dart';
import 'tv_sheet.dart';
import 'welcome_page.dart';
import 'widgets.dart';
import 'tournament_page.dart';

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
    // Jeu en ligne : défis reçus (affichés par-dessus tout écran)
    _online.addListener(_onOnline);
    // Premier lancement : profil principal
    final store = PlayerStore.instance;
    if (!store.welcomed && store.players.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true, builder: (_) => const WelcomePage()));
        }
      });
    } else {
      // Partie coupée (appli fermée, téléphone éteint) : la reprendre ?
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
    }
    // Reconnexion automatique à la dernière cible
    if (board.lastId != null && !board.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => board.reconnect());
    }
  }

  final _online = OnlineService.instance;
  int? _shownInvite;

  Future<void> _offerResume() async {
    final saved = await GameSave.load();
    if (saved == null || !mounted) return;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Partie interrompue', style: Tv.title(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(saved.summary, style: Tv.title(18, color: Tv.goldLight)),
            const SizedBox(height: 8),
            const Text('La reprendre là où elle s\'est arrêtée ?'),
          ],
        ),
        actions: [
          TextButton(
              key: const ValueKey('resume-no'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ABANDONNER')),
          FilledButton(
              key: const ValueKey('resume-yes'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('REPRENDRE')),
        ],
      ),
    );
    if (!mounted) return;
    if (go != true) {
      GameSave.clear();
      return;
    }
    final tn = saved.tournament;
    if (tn == null) {
      _open(GamePage(game: saved.game));
      return;
    }
    final local = LocalTournamentStore.instance;
    await local.load();
    final uid = '${tn['uid']}';
    if (!mounted) return;
    if (local.byUid(uid) == null) {
      // tournoi supprimé entre-temps : la partie seule
      _open(GamePage(game: saved.game));
      return;
    }
    _open(LocalTournamentPage(uid: uid, resume: (
      saved.game,
      (tn['r'] as num?)?.toInt() ?? 0,
      (tn['s'] as num?)?.toInt() ?? 0
    )));
  }

  void _onOnline() {
    final inv = _online.invite;
    if (inv == null || inv.id == _shownInvite || !mounted) return;
    _shownInvite = inv.id;
    showInviteDialog(context, inv);
  }

  @override
  void dispose() {
    _online.removeListener(_onOnline);
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

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    AudioService.instance.startMusic();
    TvLink.instance.pushLobby();
    _loadStart();
  }

  @override
  Widget build(BuildContext context) {
    // Petit téléphone : barre du haut resserrée (icônes, profil en avatar)
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      body: TvBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 10),
            child: Column(
              children: [
                // ─── Barre du haut ───
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      // Largeur bornée : le titre rétrécit au lieu de pousser
                      // la pastille de la cible hors de la barre
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: compact ? 130 : 190),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ShaderMask(
                            shaderCallback: (r) =>
                                Tv.goldGradient.createShader(r),
                            child: Text('FOCLABOARD',
                                style: Tv.title(30, color: Colors.white)
                                    .copyWith(letterSpacing: 2)),
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 6 : 12),
                      // Cible : pastille étroite à gauche (état + outils)
                      // (prend la place libre : les boutons restent à droite)
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: compact ? 170 : 200),
                                child: ListenableBuilder(
                                  listenable: board,
                                  builder: (context, _) => _BoardPill(
                                    board: board,
                                    onChoose: () => _open(const ConnectPage()),
                                    onDiagnostic: () =>
                                        _open(const DiagnosticPage()),
                                    onCalibrate: () =>
                                        _open(const CalibrationPage()),
                                  ),
                                ),
                              ),
                            ),
                            const _NetPill(),
                          ],
                        ),
                      ),
                      _BarButton(
                        key: const ValueKey('bar-stats'),
                        icon: const Icon(Icons.leaderboard, size: 24),
                        label: 'STATS',
                        onTap: () => _open(const RankingPage()),
                      ),
                      ListenableBuilder(
                        listenable: TvLink.instance,
                        builder: (context, _) => _BarButton(
                          key: const ValueKey('bar-tv'),
                          icon: Icon(
                              TvLink.instance.linked
                                  ? Icons.connected_tv
                                  : Icons.tv,
                              size: 24,
                              color: TvLink.instance.linked ? Tv.green : null),
                          label: 'TV',
                          onTap: () => showTvSheet(context),
                        ),
                      ),
                      _BarButton(
                        key: const ValueKey('bar-sound'),
                        icon: const Icon(Icons.volume_up, size: 24),
                        label: 'SON',
                        onTap: () => showSoundSettings(context),
                      ),
                      ListenableBuilder(
                        listenable: PlayerStore.instance,
                        builder: (context, _) {
                          final me = PlayerStore.instance.owner;
                          return _BarButton(
                            key: const ValueKey('me-chip'),
                            icon: _MeChip(me: me),
                            label: me == null ? 'JOUEURS' : 'PROFIL',
                            onTap: () => _open(me == null
                                ? const PlayersPage()
                                : PlayerDetailPage(player: me)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ─── Tuiles (4 + 4) ───
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _row([
                          _Tile(
                            tint: Tv.gold,
                            anim: _spin,
                            kicker: 'X01 · FREEZE',
                            title: '$_start',
                            gold: true,
                            spin: _spin,
                            onTap: () => _open(const SetupPage(kind: 'x01')),
                          ),
                          _Tile(
                            tint: const Color(0xFF21C46B),
                            anim: _spin,
                            art: TileArt.cricket,
                            kicker: '8 VARIANTES',
                            title: 'CRICKET',
                            icon: Icons.grid_view_rounded,
                            onTap: () =>
                                _open(const SetupPage(kind: 'cricket')),
                          ),
                          _Tile(
                            tint: const Color(0xFFFF4D4D),
                            anim: _spin,
                            art: TileArt.match,
                            kicker: '01 + CRICKET',
                            title: 'MATCH',
                            icon: Icons.emoji_events,
                            onTap: () => _open(const SetupPage(kind: 'match')),
                          ),
                          _Tile(
                            tint: const Color(0xFF3BA7FF),
                            anim: _spin,
                            art: TileArt.practice,
                            kicker: '$_practiceCount JEUX',
                            title: 'ENTRAÎNEMENT',
                            icon: Icons.fitness_center,
                            onTap: () =>
                                _open(const SetupPage(kind: 'practice')),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _row([
                          _Tile(
                            tint: const Color(0xFFB45CFF),
                            anim: _spin,
                            art: TileArt.party,
                            kicker: '$_partyCount JEUX',
                            title: 'FÊTE',
                            icon: Icons.celebration,
                            onTap: () => _open(const SetupPage(kind: 'party')),
                          ),
                          ListenableBuilder(
                            listenable: _online,
                            builder: (context, _) {
                              final n = _online.players.length;
                              return _Tile(
                                tint: const Color(0xFF22D3C5),
                                anim: _spin,
                                art: TileArt.online,
                                kicker: _online.resumeRoom != null
                                    ? 'PARTIE À REPRENDRE'
                                    : n == 0
                                        ? '1 CONTRE 1 · VIDÉO'
                                        : '$n JOUEUR${n > 1 ? 'S' : ''} EN LIGNE',
                                title: 'EN LIGNE',
                                icon: Icons.public,
                                onTap: () => _open(const OnlinePage()),
                              );
                            },
                          ),
                          _Tile(
                            tint: const Color(0xFFFF9F1C),
                            anim: _spin,
                            art: TileArt.tournament,
                            kicker: 'ÉLIMINATION · EN LIGNE',
                            title: 'TOURNOIS',
                            icon: Icons.account_tree,
                            onTap: () => _open(const TournamentsPage()),
                          ),
                          ListenableBuilder(
                            listenable: PlayerStore.instance,
                            builder: (context, _) => _Tile(
                              key: const ValueKey('tile-options'),
                              tint: const Color(0xFF8A93A6),
                              anim: _spin,
                              art: TileArt.options,
                              kicker:
                                  '${PlayerStore.instance.players.length} JOUEUR${PlayerStore.instance.players.length > 1 ? 'S' : ''} · RÉGLAGES',
                              title: 'OPTIONS',
                              icon: Icons.tune,
                              onTap: () => _open(const OptionsPage()),
                            ),
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
  /// Couleur de la tuile (dégradé, bordure lumineuse, illustration).
  final Color tint;
  final Animation<double> anim;
  final TileArt? art;
  final String kicker;
  final String title;
  final IconData? icon;
  final bool gold;
  final Animation<double>? spin;
  final VoidCallback onTap;
  const _Tile(
      {super.key,
      required this.tint,
      required this.anim,
      this.art,
      required this.kicker,
      required this.title,
      required this.onTap,
      this.icon,
      this.gold = false,
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
              colors: [
                Color.lerp(tint, Colors.black, 0.50)!,
                Color.lerp(tint, Colors.black, 0.86)!,
              ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.5),
          boxShadow: [
            BoxShadow(color: tint.withValues(alpha: 0.22), blurRadius: 14),
          ],
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
                  else if (art != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                            painter: TileArtPainter(art!,
                                Color.lerp(tint, Colors.white, 0.35)!, anim)),
                      ),
                    ),
                  // Reflet en haut de la tuile
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: c.maxHeight * 0.45,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kicker,
                            style: Tv.label(12, color: Colors.white70)),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title,
                              style: Tv.title(38,
                                      color: gold ? Tv.goldLight : Colors.white)
                                  .copyWith(shadows: [
                                Shadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 8),
                              ])),
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
/// Bouton de la barre du haut : icône et petit titre dessous.
class _BarButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _BarButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Tv.panel2.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Tv.gold.withValues(alpha: 0.45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 3, 10, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 26, child: Center(child: icon)),
                  const SizedBox(height: 1),
                  Text(label, style: Tv.label(10, color: Tv.text)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Profil principal : photo et rang.
class _MeChip extends StatelessWidget {
  final PlayerProfile? me;
  const _MeChip({required this.me});

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        me == null
            ? const Icon(Icons.groups, size: 24)
            : PlayerAvatar.of(me, size: 26),
        if (me != null && me.rating != null) ...[
          const SizedBox(width: 5),
          RankChip(me.key, size: 12),
        ],
      ],
    );
  }
}

/// État de la cible en pastille : touche = choisir une cible, menu = outils.
/// Hors ligne ou parties pas encore envoyées : petite pastille dans la barre
/// (rien quand tout va bien). Toucher = explication + nouvel essai.
class _NetPill extends StatelessWidget {
  const _NetPill();

  @override
  Widget build(BuildContext context) {
    final store = PlayerStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([GbServer.reachable, store]),
      builder: (context, _) {
        final off = !GbServer.reachable.value;
        final n = store.pending.length;
        if (!off && n == 0) return const SizedBox.shrink();
        final color = off ? Tv.red : Tv.gold;
        final text = off
            ? (n > 0 ? 'Hors ligne · $n en attente' : 'Hors ligne')
            : '$n à envoyer';
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: text,
            child: InkWell(
              key: const ValueKey('net-pill'),
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                store.flush();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(off
                        ? 'Pas d\'internet : tu peux jouer quand même. '
                            '${n == 0 ? 'Les parties seront envoyées' : n == 1 ? '1 partie en attente, envoyée' : '$n parties en attente, envoyées'} '
                            'au serveur dès le retour du réseau.'
                        : 'Envoi de ${plural(n, 'partie', 'parties')} au serveur…')));
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(off ? Icons.cloud_off : Icons.cloud_upload,
                        size: 18, color: color),
                    if (n > 0) ...[
                      const SizedBox(width: 4),
                      Text('$n', style: Tv.title(14)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      constraints: const BoxConstraints(minWidth: 60),
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
