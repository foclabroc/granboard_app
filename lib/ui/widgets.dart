import 'package:flutter/material.dart';

import '../board_service.dart';
import '../players.dart';
import 'theme.dart';

/// Pastille de couleur avec l'initiale du joueur.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const PlayerAvatar(
      {super.key, required this.name, required this.color, this.size = 36});

  factory PlayerAvatar.of(PlayerProfile p, {double size = 36}) =>
      PlayerAvatar(name: p.name, color: p.color, size: size);

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(initial,
          style: TextStyle(
              color:
                  color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.45)),
    );
  }
}

/// Bandeau affiché quand la cible n'est pas connectée.
class BoardBanner extends StatelessWidget {
  const BoardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final board = BoardService.instance;
    return ListenableBuilder(
      listenable: board,
      builder: (context, _) {
        if (board.isConnected) return const SizedBox.shrink();
        final connecting = board.status == BoardStatus.connecting;
        // Bandeau fin (paysage : chaque pixel de hauteur compte)
        return Container(
          height: 34,
          color: Tv.red.withValues(alpha: 0.28),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bluetooth_disabled, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    connecting
                        ? 'Connexion à la cible…'
                        : board.error ?? 'Cible non connectée',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.title(15)),
              ),
              if (!connecting && board.lastId != null)
                TextButton(
                    onPressed: board.reconnect,
                    child: const Text('RECONNECTER')),
            ],
          ),
        );
      },
    );
  }
}
