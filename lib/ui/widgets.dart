import 'package:flutter/material.dart';

import '../board_service.dart';
import '../players.dart';

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
        return MaterialBanner(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          leading: connecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bluetooth_disabled),
          content: Text(connecting
              ? 'Connexion à la cible…'
              : board.error ?? 'Cible non connectée'),
          actions: [
            if (!connecting && board.lastId != null)
              TextButton(
                  onPressed: board.reconnect, child: const Text('Reconnecter')),
            if (connecting || board.lastId == null) const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}

Future<String?> askName(BuildContext context,
    {String title = 'Nouveau joueur', String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 16,
        decoration: const InputDecoration(labelText: 'Nom'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK')),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}
