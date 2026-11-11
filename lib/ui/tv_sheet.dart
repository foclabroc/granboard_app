import 'package:flutter/material.dart';

import '../main.dart' show GranBoardAppState;
import '../server.dart';
import '../tv_link.dart';
import 'theme.dart';

/// Écrans reliés (TV, tablette…) : ajout, retrait, choix du son.
Future<void> showTvSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tv.panel,
      showDragHandle: true,
      builder: (_) => const _TvSheet(),
    );

/// Choix de l'appareil qui joue le son (téléphone ou un écran relié).
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
          ChoiceChip(
            showCheckmark: false,
            avatar: const Icon(Icons.smartphone, size: 18),
            label: const Text('Téléphone'),
            selected: link.soundOn == TvLink.phone,
            onSelected: (_) => link.setSoundOn(TvLink.phone),
          ),
          for (final s in link.screens)
            ChoiceChip(
              showCheckmark: false,
              avatar: Icon(s.name == 'TV' ? Icons.tv : Icons.tablet, size: 18),
              label: Text(s.label),
              selected: link.soundOn == s.code,
              onSelected: (_) => link.setSoundOn(s.code),
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
        _error =
            e.code == 'tv_code' ? 'Code inconnu : vérifie l\'écran' : e.message;
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
                    if (link.soundOn == s.code)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
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
              const TvSection('Le son sort sur',
                  padding: EdgeInsets.only(top: 16, bottom: 8)),
              const SoundTargetPicker(),
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
