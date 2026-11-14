import 'package:flutter/material.dart';

import '../main.dart' show GranBoardAppState;
import '../server.dart';
import '../tv_link.dart';
import 'theme.dart';

/// Écrans reliés (TV, tablette…) : ajout, retrait, choix du son.
Future<void> showTvSheet(BuildContext context) =>
    showAppSheet(context, builder: (_) => const _TvSheet());

/// Choix des appareils qui jouent le son (téléphone et/ou écrans reliés),
/// plusieurs à la fois possibles.
class SoundTargetPicker extends StatelessWidget {
  const SoundTargetPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final link = TvLink.instance;
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          FilterChip(
            showCheckmark: false,
            avatar: Icon(
                link.soundsOn(TvLink.phone)
                    ? Icons.volume_up
                    : Icons.smartphone,
                size: 18),
            label: const Text('Téléphone'),
            selected: link.soundsOn(TvLink.phone),
            onSelected: (_) => link.toggleSound(TvLink.phone),
          ),
          for (final s in link.screens)
            FilterChip(
              showCheckmark: false,
              avatar: Icon(
                  link.soundsOn(s.code)
                      ? Icons.volume_up
                      : s.name == 'TV'
                          ? Icons.tv
                          : Icons.tablet,
                  size: 18),
              label: Text(s.label),
              selected: link.soundsOn(s.code),
              onSelected: (_) => link.toggleSound(s.code),
            ),
        ],
      ),
    );
  }
}

class _TvSheet extends StatefulWidget {
  const _TvSheet();

  @override
  State<_TvSheet> createState() => _TvSheetState();
}

class _TvSheetState extends State<_TvSheet> {
  final link = TvLink.instance;
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_code.text.trim().length != 4) {
      setState(() => _error = 'Le code fait 4 caractères');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await link.link(_code.text);
      link.pushLobby();
      _code.clear();
      setState(() => _busy = false);
    } on ApiError catch (e) {
      setState(() {
        _error = e.code == 'tv_code'
            ? 'Code inconnu : vérifie l\'écran'
            : e.offline
                ? 'Pas d\'internet et écran introuvable sur le Wi-Fi : '
                    'mets le téléphone sur le même Wi-Fi que l\'écran'
                : e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TvSection('Écrans', padding: EdgeInsets.only(bottom: 8)),
            if (link.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(link.error!, style: Tv.title(15, color: Tv.red)),
              ),
            for (final s in link.screens)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Tv.panel2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Tv.line),
                ),
                child: Row(
                  children: [
                    Icon(s.name == 'TV' ? Icons.tv : Icons.tablet,
                        color: Tv.green),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text(s.label.toUpperCase(), style: Tv.title(20))),
                    if (link.lanWorks(s))
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message: 'Relié aussi par le Wi-Fi local',
                          child: Icon(Icons.wifi, color: Tv.green, size: 20),
                        ),
                      ),
                    if (link.soundsOn(s.code))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.volume_up, color: Tv.gold),
                      ),
                    TextButton.icon(
                      onPressed: () => link.unlink(s.code),
                      icon: const Icon(Icons.link_off),
                      label: const Text('DÉCONNECTER'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
                link.linked
                    ? 'Ajouter un autre écran : entre le code qu\'il affiche'
                    : 'Allume Foclaboard sur la TV (ou la tablette) et entre le code affiché :',
                style: Tv.label(14, color: Tv.text)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _code,
                    enabled: !_busy,
                    autofocus: !link.linked,
                    maxLength: 4,
                    textCapitalization: TextCapitalization.characters,
                    style: Tv.title(30).copyWith(letterSpacing: 10),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'ABCD',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _link(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _link,
                  icon: const Icon(Icons.cast),
                  label: const Text('RELIER'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: Tv.title(15, color: Tv.red)),
              ),
            if (link.linked) ...[
              const TvSection('Le son sort sur (un ou plusieurs)',
                  padding: EdgeInsets.only(top: 16, bottom: 8)),
              const SoundTargetPicker(),
              SwitchListTile(
                key: const ValueKey('tv-anim'),
                contentPadding: EdgeInsets.zero,
                title: Text('Animations complètes sur l\'écran',
                    style: Tv.title(17)),
                subtitle: const Text(
                    'Fond animé, cible qui pulse et anneau de LED. Coupé : '
                    'plus fluide sur une TV peu puissante (les fléchettes, '
                    'vidéos et bandeaux restent animés).'),
                value: link.fullAnim,
                onChanged: (v) => link.setFullAnim(v),
              ),
              if (link.camScreens.isNotEmpty) const CamPanel(),
            ] else ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context
                      .findAncestorStateOfType<GranBoardAppState>()
                      ?.setTvMode(true);
                },
                icon: const Icon(Icons.connected_tv),
                label: const Text('CET APPAREIL DEVIENT UN ÉCRAN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Caméra d'un écran (tablette) affichée sur un autre (TV) : choix des 2
/// écrans, allumer / éteindre, caméra avant / arrière, position, taille.
class CamPanel extends StatefulWidget {
  const CamPanel({super.key});

  @override
  State<CamPanel> createState() => _CamPanelState();
}

class _CamPanelState extends State<CamPanel> {
  final link = TvLink.instance;
  String? _from, _to;

  static const _posLabels = {
    'tr': 'HAUT DROITE',
    'tl': 'HAUT GAUCHE',
    'br': 'BAS DROITE',
    'bl': 'BAS GAUCHE',
    'full': 'PLEIN ÉCRAN',
  };
  static const _sizeLabels = {'s': 'PETITE', 'm': 'MOYENNE', 'l': 'GRANDE'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) {
        final list = link.camScreens;
        final cam = link.cam;
        // sources : cet appareil + les écrans ; cibles : les écrans
        final sources = <(String, String, IconData)>[
          (TvLink.phone, 'Cet appareil', Icons.phone_android),
          for (final s in list)
            (s.code, s.label, s.name == 'TV' ? Icons.tv : Icons.tablet),
        ];
        final codes = list.map((s) => s.code).toList();
        // par défaut : la tablette (écran) filme si 2 écrans, sinon cet
        // appareil ; la TV affiche
        var from = cam?['from'] as String? ?? _from;
        if (from == null ||
            (from != TvLink.phone && !codes.contains(from)) ||
            (from != TvLink.phone && list.length < 2)) {
          from = list.length >= 2
              ? (list.where((s) => s.name != 'TV').firstOrNull?.code ??
                  TvLink.phone)
              : TvLink.phone;
        }
        var to = cam?['to'] as String? ?? _to;
        if (to == null || to == from || !codes.contains(to)) {
          to = (list
                      .where((s) => s.code != from && s.name == 'TV')
                      .firstOrNull ??
                  list.firstWhere((s) => s.code != from))
              .code;
        }
        final on = cam != null;
        final targets = [
          for (final x in sources)
            if (x.$1 != TvLink.phone && x.$1 != from) x
        ];

        Widget chips(String sel, Iterable<(String, String, IconData)> items,
                String key, void Function(String) pick) =>
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final s in items)
                ChoiceChip(
                  key: ValueKey('$key-${s.$1}'),
                  showCheckmark: false,
                  avatar: Icon(s.$3, size: 18),
                  label: Text(s.$2),
                  selected: s.$1 == sel,
                  onSelected: (_) => pick(s.$1),
                ),
            ]);

        void restart(String f, String t) {
          setState(() {
            _from = f;
            _to = t;
          });
          if (on) link.startCam(f, t);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TvSection('Caméra sur un écran',
                padding: EdgeInsets.only(top: 16, bottom: 8)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FILMER AVEC', style: Tv.label(12)),
                      const SizedBox(height: 4),
                      chips(
                          from,
                          [
                            for (final x in sources)
                              // un écran ne filme que s'il en reste un pour afficher
                              if (x.$1 == TvLink.phone || list.length >= 2) x
                          ],
                          'cam-from', (c) {
                        final t = c == to
                            ? list.firstWhere((s) => s.code != c).code
                            : to!;
                        restart(c, t);
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AFFICHER SUR', style: Tv.label(12)),
                      const SizedBox(height: 4),
                      chips(to, targets, 'cam-to', (c) => restart(from!, c)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton.icon(
                key: const ValueKey('cam-toggle'),
                style:
                    on ? FilledButton.styleFrom(backgroundColor: Tv.red) : null,
                onPressed: () =>
                    on ? link.stopCam() : link.startCam(from!, to!),
                icon: Icon(on ? Icons.videocam_off : Icons.videocam),
                label: Text(on ? 'COUPER LA CAMÉRA' : 'ALLUMER LA CAMÉRA'),
              ),
              if (on) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: const ValueKey('cam-front'),
                  onPressed: () => link.setCam(front: cam['front'] != true),
                  icon: const Icon(Icons.flip_camera_android),
                  label: Text(
                      cam['front'] == true ? 'CAMÉRA AVANT' : 'CAMÉRA ARRIÈRE'),
                ),
              ],
            ]),
            if (on) ...[
              const SizedBox(height: 10),
              Text('POSITION SUR L\'ÉCRAN', style: Tv.label(12)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final p in TvLink.camPositions)
                  ChoiceChip(
                    key: ValueKey('cam-pos-$p'),
                    showCheckmark: false,
                    label: Text(_posLabels[p]!),
                    selected: cam['pos'] == p,
                    onSelected: (_) => link.setCam(pos: p),
                  ),
              ]),
              if (cam['pos'] != 'full') ...[
                const SizedBox(height: 8),
                Text('TAILLE', style: Tv.label(12)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  for (final z in TvLink.camSizes)
                    ChoiceChip(
                      key: ValueKey('cam-size-$z'),
                      showCheckmark: false,
                      label: Text(_sizeLabels[z]!),
                      selected: cam['size'] == z,
                      onSelected: (_) => link.setCam(size: z),
                    ),
                ]),
              ],
            ],
            const SizedBox(height: 6),
            Text(
                'L\'image passe directement d\'un appareil à l\'autre par le Wi-Fi (sans le son). '
                'La première fois, l\'appareil qui filme demande l\'autorisation caméra.',
                style: Tv.label(12)),
          ],
        );
      },
    );
  }
}
