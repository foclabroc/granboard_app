import 'package:flutter/material.dart';

import '../board_service.dart';
import '../media.dart';
import '../players.dart';
import 'theme.dart';

/// Photo du joueur (si `id` en a une), sinon pastille de couleur avec
/// l'initiale. La photo est cerclée de la couleur du joueur.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final String? id;
  const PlayerAvatar(
      {super.key,
      required this.name,
      required this.color,
      this.size = 36,
      this.id});

  factory PlayerAvatar.of(PlayerProfile p, {double size = 36}) =>
      PlayerAvatar(name: p.name, color: p.color, size: size, id: p.key);

  @override
  Widget build(BuildContext context) {
    if (id == null) return _initial();
    return ListenableBuilder(
      listenable: MediaStore.instance,
      builder: (context, _) {
        final image = MediaStore.instance.imageOf(id!);
        if (image == null) return _initial();
        return Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size > 40 ? 3 : 2),
          decoration: BoxDecoration(
              color: color,
              gradient: playerFill(color),
              shape: BoxShape.circle),
          child: ClipOval(
            child: Image(
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _initial()),
          ),
        );
      },
    );
  }

  Widget _initial() {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final rainbow = isRainbow(color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color, gradient: playerFill(color), shape: BoxShape.circle),
      child: Text(initial,
          style: TextStyle(
              color: rainbow || color.computeLuminance() <= 0.5
                  ? Colors.white
                  : Colors.black,
              shadows: rainbow
                  ? const [Shadow(color: Colors.black87, blurRadius: 4)]
                  : null,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.45)),
    );
  }
}

/// Pastille de couleur de joueur (unie ou arc-en-ciel).
class ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool selected;
  const ColorDot(this.color,
      {super.key, this.size = 20, this.selected = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          gradient: playerFill(color),
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? Colors.white : Colors.black26,
              width: selected ? 3 : 1),
        ),
      );
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
