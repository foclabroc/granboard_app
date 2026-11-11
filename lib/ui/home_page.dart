import 'package:flutter/material.dart';

import '../board_service.dart';
import '../update_check.dart';
import 'connect_page.dart';
import 'diagnostic_page.dart';
import 'players_page.dart';
import 'setup_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final board = BoardService.instance;

  @override
  void initState() {
    super.initState();
    // Reconnexion automatique à la dernière cible
    if (board.lastId != null && !board.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => board.reconnect());
    }
  }

  Future<void> _checkUpdate() async {
    final r = await updateGateKey.currentState?.check(manual: true);
    if (!mounted || r == 1) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r == 2
            ? 'Impossible de joindre GitHub'
            : 'À jour (v$kAppVersion)')));
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GranBoard'),
        actions: [
          IconButton(
            tooltip: 'Vérifier les mises à jour',
            icon: const Icon(Icons.system_update),
            onPressed: _checkUpdate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListenableBuilder(
            listenable: board,
            builder: (context, _) => _BoardCard(
              board: board,
              onChoose: () => _open(const ConnectPage()),
              onDiagnostic: () => _open(const DiagnosticPage()),
            ),
          ),
          const SizedBox(height: 24),
          _BigButton(
            icon: Icons.sports_score,
            title: 'Nouvelle partie',
            subtitle: '301 · 501 · 701 · 901 · Freeze',
            color: cs.primaryContainer,
            onTap: () => _open(const SetupPage()),
          ),
          const SizedBox(height: 12),
          _BigButton(
            icon: Icons.people,
            title: 'Joueurs',
            subtitle: 'Profils et statistiques',
            color: cs.secondaryContainer,
            onTap: () => _open(const PlayersPage()),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text('v$kAppVersion',
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final BoardService board;
  final VoidCallback onChoose;
  final VoidCallback onDiagnostic;
  const _BoardCard(
      {required this.board,
      required this.onChoose,
      required this.onDiagnostic});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color, text) = switch (board.status) {
      BoardStatus.connected => (
          Icons.adjust,
          Colors.greenAccent,
          'Connectée : ${board.deviceName ?? 'GranBoard'}'
        ),
      BoardStatus.connecting => (
          Icons.bluetooth_searching,
          Colors.amberAccent,
          'Connexion à ${board.deviceName ?? 'la cible'}…'
        ),
      BoardStatus.disconnected => (
          Icons.bluetooth_disabled,
          cs.error,
          board.error ?? 'Cible non connectée'
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (board.status == BoardStatus.disconnected &&
                    board.lastId != null)
                  FilledButton.icon(
                    onPressed: board.reconnect,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnecter'),
                  ),
                if (board.isConnected)
                  OutlinedButton.icon(
                    onPressed: board.disconnect,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Déconnecter'),
                  ),
                OutlinedButton.icon(
                  onPressed: onChoose,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Choisir une cible'),
                ),
                TextButton.icon(
                  onPressed: onDiagnostic,
                  icon: const Icon(Icons.terminal),
                  label: const Text('Diagnostic'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _BigButton(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 44),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
