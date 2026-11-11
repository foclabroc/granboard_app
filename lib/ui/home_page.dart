import 'package:flutter/material.dart';

import '../audio.dart';
import '../board_service.dart';
import '../update_check.dart';
import 'connect_page.dart';
import 'dartboard.dart';
import 'diagnostic_page.dart';
import 'players_page.dart';
import 'setup_page.dart';
import 'sound_settings.dart';
import 'theme.dart';

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

  @override
  void initState() {
    super.initState();
    AudioService.instance.startMusic();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TvBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Sons',
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => showSoundSettings(context),
                  ),
                  IconButton(
                    tooltip: 'Vérifier les mises à jour',
                    icon: const Icon(Icons.system_update),
                    onPressed: _checkUpdate,
                  ),
                ],
              ),
              _Hero(spin: _spin),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: board,
                builder: (context, _) => _BoardBar(
                  board: board,
                  onChoose: () => _open(const ConnectPage()),
                  onDiagnostic: () => _open(const DiagnosticPage()),
                ),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.sports_score,
                title: 'Nouvelle partie',
                subtitle: '301 · 501 · 701 · 901 · Freeze',
                primary: true,
                onTap: () => _open(const SetupPage()),
              ),
              const SizedBox(height: 10),
              _MenuButton(
                icon: Icons.groups,
                title: 'Joueurs',
                subtitle: 'Profils et statistiques',
                onTap: () => _open(const PlayersPage()),
              ),
              const SizedBox(height: 28),
              Center(
                  child: Text('VERSION $kAppVersion',
                      style: Tv.label(12, color: Tv.line))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Animation<double> spin;
  const _Hero({required this.spin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Tv.gold.withValues(alpha: 0.25),
                  blurRadius: 60,
                  spreadRadius: 4),
            ],
          ),
          child: RotationTransition(
            turns: spin,
            child: const Dartboard(size: 210, showNumbers: true),
          ),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (r) => Tv.goldGradient.createShader(r),
          child: Text('GRANBOARD',
              style:
                  Tv.title(52, color: Colors.white).copyWith(letterSpacing: 4)),
        ),
        const SizedBox(height: 4),
        Text('DARTS  ·  X01  ·  FREEZE', style: Tv.label(14)),
      ],
    );
  }
}

class _BoardBar extends StatelessWidget {
  final BoardService board;
  final VoidCallback onChoose;
  final VoidCallback onDiagnostic;
  const _BoardBar(
      {required this.board,
      required this.onChoose,
      required this.onDiagnostic});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (board.status) {
      BoardStatus.connected => (Tv.green, board.deviceName ?? 'GranBoard'),
      BoardStatus.connecting => (Tv.gold, 'Connexion…'),
      BoardStatus.disconnected => (
          Tv.red,
          board.error ?? 'Cible non connectée'
        ),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Tv.line),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color, blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CIBLE', style: Tv.label(11)),
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(18)),
              ],
            ),
          ),
          if (board.status == BoardStatus.disconnected && board.lastId != null)
            IconButton(
              tooltip: 'Reconnecter',
              icon: const Icon(Icons.refresh, color: Tv.gold),
              onPressed: board.reconnect,
            ),
          IconButton(
            tooltip: 'Choisir une cible',
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: onChoose,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'diag') onDiagnostic();
              if (v == 'off') board.disconnect();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'diag', child: Text('Diagnostic')),
              if (board.isConnected)
                const PopupMenuItem(value: 'off', child: Text('Déconnecter')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;
  const _MenuButton(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.primary = false});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.black : Tv.text;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: primary ? Tv.goldGradient : Tv.panelGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary ? Tv.goldDark : Tv.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 38, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(), style: Tv.title(26, color: fg)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Tv.label(14,
                              color: primary ? Colors.black87 : Tv.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: fg, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
