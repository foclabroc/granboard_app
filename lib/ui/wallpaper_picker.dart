import 'package:flutter/material.dart';

import '../tv_link.dart';
import 'theme.dart';
import 'wallpaper.dart';

/// Choix de l'image du thème « Fond d'écran » : au hasard, images de
/// l'appli, photos du téléphone (+ pour ajouter, appui long pour retirer).
class WallpaperPicker extends StatelessWidget {
  const WallpaperPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final w = Wallpaper.instance;
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        Widget tile(String c,
            {Widget? child, VoidCallback? onLongPress, Key? key}) {
          final on = w.choice == c;
          final img = c == 'add' ? null : w.imageOf(c, thumb: true);
          return InkWell(
            key: key ?? ValueKey('wall-$c'),
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              if (c == 'add') {
                if (!await w.addFromGallery()) return;
              } else {
                await w.choose(c);
              }
              TvLink.instance.pushLobby();
            },
            onLongPress: onLongPress,
            child: Container(
              width: 112,
              height: 63,
              decoration: BoxDecoration(
                color: Tv.panel2,
                borderRadius: BorderRadius.circular(10),
                image: img == null
                    ? null
                    : DecorationImage(image: img, fit: BoxFit.cover),
                border: Border.all(
                    color: on ? Tv.gold : Tv.line, width: on ? 3 : 1),
              ),
              alignment: Alignment.center,
              child: child ??
                  (on
                      ? Icon(Icons.check_circle, color: Tv.gold, size: 22)
                      : null),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TvSection('Image',
                padding: EdgeInsets.only(top: 16, bottom: 8)),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                tile('random',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle,
                            color: w.choice == 'random' ? Tv.gold : Tv.text),
                        Text('AU HASARD', style: Tv.title(13)),
                      ],
                    )),
                for (var i = 1; i <= Wallpaper.assetCount; i++)
                  tile('asset:$i'),
                for (final f in w.files)
                  tile('file:$f', onLongPress: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Retirer cette image ?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('ANNULER')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('RETIRER')),
                        ],
                      ),
                    );
                    if (ok == true) await w.remove(f);
                  }),
                tile('add',
                    key: const ValueKey('wall-add'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            color: Tv.text),
                        Text('MES IMAGES', style: Tv.title(13)),
                      ],
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Au hasard : une nouvelle image à chaque lancement (les '
                'tiennes comprises). Appui long sur une de tes images pour la '
                'retirer. La TV affiche la même image, sauf tes photos '
                '(image au hasard).',
                style: Tv.label(11)),
          ],
        );
      },
    );
  }
}
