import 'package:flutter/material.dart';

import '../board_lights.dart';
import '../board_service.dart';
import 'theme.dart';

/// Réglages des lumières de la cible (GranBoard 3s) + essai.
Future<void> showLightsSheet(BuildContext context) => showAppSheet(
      context,
      builder: (_) => const _LightsSheet(),
    );

class _LightsSheet extends StatefulWidget {
  const _LightsSheet();

  @override
  State<_LightsSheet> createState() => _LightsSheetState();
}

class _LightsSheetState extends State<_LightsSheet> {
  final lights = BoardLights.instance;

  Future<void> _color(int v) async {
    await lights.setNumberColor(v);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final board = BoardService.instance;
    final status = !board.isConnected
        ? 'Cible pas connectée'
        : lights.writer == null
            ? 'Cette cible ne reçoit pas de commandes de lumière'
            : 'Lumières disponibles sur ${board.deviceName ?? 'la cible'}';
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('LUMIÈRES DE LA CIBLE', style: Tv.title(22, color: Tv.gold)),
        const SizedBox(height: 4),
        Text(status, style: Tv.label(13)),
        SwitchListTile(
          key: const ValueKey('lights-ring'),
          contentPadding: EdgeInsets.zero,
          title: Text('Contour lumineux', style: Tv.title(18)),
          subtitle: const Text('Couleur du joueur en cours, clignote sur '
              'chaque touche (1 à 3 fois : simple, double, triple), vague '
              'sur un 180 ou une victoire, rouge sur un bust'),
          value: lights.enabled,
          onChanged: (v) async {
            await lights.setEnabled(v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          key: const ValueKey('lights-numbers'),
          contentPadding: EdgeInsets.zero,
          title: Text('Numéros à viser', style: Tv.title(18)),
          subtitle: const Text('Allumés : numéros encore ouverts '
              'en Cricket, prochaine fléchette de la fin en 01, cible de '
              'l\'entraînement (le bull ne s\'allume pas)'),
          value: lights.numbers,
          onChanged: (v) async {
            await lights.setNumbers(v);
            if (mounted) setState(() {});
          },
        ),
        SwitchListTile(
          key: const ValueKey('lights-idle'),
          contentPadding: EdgeInsets.zero,
          title: Text('Animation d\'attente', style: Tv.title(18)),
          subtitle: const Text('Hors partie, les numéros jouent l\'animation '
              'du contour choisie dans les options'),
          value: lights.idleAnim,
          onChanged: lights.numbers
              ? (v) async {
                  await lights.setIdleAnim(v);
                  if (mounted) setState(() {});
                }
              : null,
        ),
        Row(
          children: [
            Expanded(
              child: Text('Couleur des numéros : ${lights.numberColor}',
                  style: Tv.title(18)),
            ),
            IconButton(
              key: const ValueKey('numcolor-minus'),
              onPressed: lights.numberColor <= 1
                  ? null
                  : () => _color(lights.numberColor - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              key: const ValueKey('numcolor-plus'),
              onPressed: lights.numberColor >= 30
                  ? null
                  : () => _color(lights.numberColor + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Text(
            'Chaque valeur allume les 20 numéros 2 s : note la couleur '
            'qu\'elle donne (5 = bleu / blanc sur ta 3s).',
            style: Tv.label(11)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('lights-test'),
          onPressed: lights.writer == null ? null : lights.test,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('ESSAYER'),
        ),
        const SizedBox(height: 6),
        Text(
            'Protocole non officiel (relevé sur une GranBoard 3s) : '
            'si rien ne s\'allume, ta cible ne le reconnaît pas.',
            style: Tv.label(11)),
      ],
    );
  }
}
