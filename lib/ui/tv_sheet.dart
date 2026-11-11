import 'package:flutter/material.dart';

import '../main.dart' show GranBoardAppState;
import '../server.dart';
import '../tv_link.dart';
import 'theme.dart';

/// Relier une TV (code affiché sur l'écran TV), ou faire de cet appareil l'écran.
Future<void> showTvSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tv.panel,
      showDragHandle: true,
      builder: (_) => const _TvSheet(),
    );

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
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() {
        _error = e.code == 'tv_code'
            ? 'Code inconnu : vérifie l\'écran TV'
            : e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TvSection('Écran TV', padding: EdgeInsets.only(bottom: 10)),
            if (link.linked) ...[
              Row(
                children: [
                  const Icon(Icons.tv, color: Tv.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TV RELIÉE · CODE ${link.code}',
                            style: Tv.title(22)),
                        Text(
                            link.error ??
                                'La partie s\'affiche sur la TV, le son passe par la TV.',
                            style: Tv.label(13,
                                color: link.error == null ? Tv.muted : Tv.red)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await link.unlink();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.link_off),
                    label: const Text('DÉCONNECTER'),
                  ),
                ],
              ),
            ] else ...[
              if (link.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(link.error!, style: Tv.title(15, color: Tv.red)),
                ),
              Text('Allume GranBoard sur la TV et entre le code affiché :',
                  style: Tv.label(14, color: Tv.text)),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _code,
                      enabled: !_busy,
                      autofocus: true,
                      maxLength: 4,
                      textCapitalization: TextCapitalization.characters,
                      style: Tv.title(32).copyWith(letterSpacing: 10),
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
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context
                      .findAncestorStateOfType<GranBoardAppState>()
                      ?.setTvMode(true);
                },
                icon: const Icon(Icons.connected_tv),
                label: const Text('CET APPAREIL DEVIENT L\'ÉCRAN TV'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
