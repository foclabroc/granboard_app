import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../players.dart';
import '../server.dart';
import 'theme.dart';

/// Connexion ou création d'un compte (pseudo + code PIN à 4 chiffres).
/// Renvoie le compte mémorisé sur le téléphone, ou null.
Future<PlayerProfile?> showAccountPage(BuildContext context,
    {String? pseudo, bool create = false}) {
  return Navigator.push<PlayerProfile>(
    context,
    MaterialPageRoute(
        builder: (_) => AccountPage(initialPseudo: pseudo, create: create)),
  );
}

class AccountPage extends StatefulWidget {
  final String? initialPseudo;
  final bool create;
  const AccountPage({super.key, this.initialPseudo, this.create = false});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final _pseudo = TextEditingController(text: widget.initialPseudo ?? '');
  late bool _create = widget.create;
  String _pin = '';
  String? _pin1; // création : premier code tapé, à confirmer
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  void _key(String k) {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 4) {
        _pin += k;
      }
    });
    if (_pin.length == 4) _submit();
  }

  Future<void> _submit() async {
    final pseudo = _pseudo.text.trim();
    if (pseudo.length < 2) {
      setState(() {
        _error = 'Entre d\'abord ton pseudo';
        _pin = '';
      });
      return;
    }
    if (_create && _pin1 == null) {
      setState(() {
        _pin1 = _pin;
        _pin = '';
      });
      return;
    }
    if (_create && _pin1 != _pin) {
      setState(() {
        _error = 'Les deux codes sont différents, recommence';
        _pin1 = null;
        _pin = '';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final store = PlayerStore.instance;
      final p = _create
          ? await store.register(pseudo, _pin)
          : await store.login(pseudo, _pin);
      if (mounted) Navigator.pop(context, p);
    } on ApiError catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = e.message;
        _pin = '';
        _pin1 = null;
        _busy = false;
      });
    }
  }

  void _switch(bool create) => setState(() {
        _create = create;
        _pin = '';
        _pin1 = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final step = !_create
        ? 'TON CODE'
        : _pin1 == null
            ? 'CHOISIS UN CODE'
            : 'CONFIRME LE CODE';

    return Scaffold(
      appBar: AppBar(
          title: Text(_create ? 'NOUVEAU JOUEUR' : 'CONNEXION D\'UN JOUEUR')),
      body: SafeArea(
        child: Row(
          children: [
            // Pseudo et choix du mode
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: false, label: Text('J\'AI UN COMPTE')),
                      ButtonSegment(
                          value: true, label: Text('CRÉER UN COMPTE')),
                    ],
                    selected: {_create},
                    onSelectionChanged: (s) => _switch(s.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pseudo,
                    enabled: !_busy,
                    maxLength: 16,
                    textCapitalization: TextCapitalization.words,
                    style: Tv.title(24),
                    decoration: const InputDecoration(
                      labelText: 'Pseudo',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Text(
                    _create
                        ? 'Ton compte est enregistré sur le serveur : tu '
                            'retrouves tes stats sur n\'importe quel téléphone '
                            'avec ton pseudo et ton code.'
                        : 'Une fois connecté, le joueur reste mémorisé sur '
                            'ce téléphone.',
                    style: Tv.label(13, color: Tv.muted),
                  ),
                ],
              ),
            ),
            // Code PIN
            SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
                child: Column(
                  children: [
                    Text(step, style: Tv.label(14, color: Tv.gold)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _pin.length
                                  ? Tv.gold
                                  : Colors.transparent,
                              border: Border.all(color: Tv.gold, width: 2),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 22,
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: LinearProgressIndicator())
                          : Text(_error ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Tv.title(14, color: Tv.red)),
                    ),
                    Expanded(child: _Keypad(onKey: _key)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: [
        for (final r in rows)
          Expanded(
            child: Row(
              children: [
                for (final k in r)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: k.isEmpty
                          ? const SizedBox()
                          : Material(
                              color: Tv.panel2,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => onKey(k),
                                child: Center(
                                  child: k == '⌫'
                                      ? const Icon(Icons.backspace_outlined)
                                      : Text(k, style: Tv.title(26)),
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
