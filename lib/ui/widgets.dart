import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../board_service.dart';
import '../game/bot.dart';
import '../media.dart';
import '../players.dart';
import 'theme.dart';
import '../rank.dart';
import '../format.dart';

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
    if (id != null && isBotId(id!)) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(Icons.smart_toy,
            size: size * 0.62,
            color:
                color.computeLuminance() <= 0.5 ? Colors.white : Colors.black),
      );
    }
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

/// Rang + note sur 20 d'un joueur (« CC 4,54 »), à la couleur du rang ;
/// rien pour un invité ou un joueur sans partie. Se met à jour tout seul.
class RankChip extends StatelessWidget {
  final String id;
  final double size;
  const RankChip(this.id, {super.key, this.size = 12});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PlayerStore.instance,
        builder: (context, _) {
          final r = PlayerStore.instance.ratingOf(id);
          if (r == null) return const SizedBox.shrink();
          final rank = rankOf(r);
          return Container(
            key: ValueKey('rank-chip-$id'),
            padding: EdgeInsets.symmetric(
                horizontal: size * 0.4, vertical: size * 0.08),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(size * 0.4),
              border: Border.all(color: rank.color, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rank.label, style: Tv.title(size, color: rank.color)),
                SizedBox(width: size * 0.3),
                Text(r.fr(2), style: Tv.title(size * 0.85, color: Tv.text)),
              ],
            ),
          );
        },
      );
}

/// Ligne du tableau des scores (01, entraînement, fête) : bande de couleur,
/// flèche du joueur en cours, nom + infos (réduits plutôt que coupés),
/// score. S'adapte à la largeur et à la hauteur données.
class ScoreRow extends StatelessWidget {
  final Color color;
  final bool current;
  final String name;
  final String info;
  final String score;
  final double height;

  /// Largeur max de la case du score.
  final double scoreWidth;

  /// Joueur : son rang s'affiche devant les infos.
  final String? id;
  const ScoreRow({
    this.id,
    super.key,
    required this.color,
    required this.current,
    required this.name,
    required this.info,
    required this.score,
    this.height = 52,
    this.scoreWidth = 78,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final narrow = w < 190;
        final sw = (w * 0.36).clamp(40.0, scoreWidth);
        final small = height < 44;
        return Container(
          height: height,
          margin: EdgeInsets.symmetric(
              horizontal: narrow ? 4 : 10, vertical: small ? 2 : 3),
          decoration: BoxDecoration(
            color: current ? const Color(0xFF2A2210) : Tv.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: current ? Tv.gold : Tv.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                  width: narrow ? 4 : 6,
                  decoration:
                      BoxDecoration(color: color, gradient: playerFill(color))),
              SizedBox(
                width: narrow ? 12 : 22,
                child: current
                    ? Icon(Icons.play_arrow,
                        color: Tv.gold, size: narrow ? 14 : 20)
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(name,
                              maxLines: 1,
                              style: Tv.title(small ? 16 : 19,
                                  color: current ? Tv.goldLight : Tv.text)),
                        ),
                      ),
                      // Rang (puis infos) sous le nom
                      if ((info.isNotEmpty || id != null) && height >= 36)
                        Row(
                          children: [
                            if (id != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: RankChip(id!, size: small ? 9 : 10),
                              ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(info,
                                    maxLines: 1,
                                    style: Tv.label(small ? 9 : 11)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                width: sw,
                color: current ? Tv.gold : Colors.black,
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(score,
                        style: Tv.title(math.min(28, height * 0.56),
                            color: current ? Colors.black : Tv.text)),
                  ),
                ),
              ),
            ],
          ),
        );
      });
}

/// Hauteur des lignes du tableau des scores pour que tout tienne dans
/// [available] ([extra] = hauteur prise par les titres d'équipe).
double scoreRowHeight(double available, int rows, {double extra = 0}) =>
    ((available - 6 - extra) / rows - 6).clamp(30.0, 52.0);

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
