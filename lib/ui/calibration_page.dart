import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../board_service.dart';
import '../granboard.dart';
import 'dartboard.dart';
import 'theme.dart';

/// Une zone à viser pendant la calibration.
class CalTarget {
  final int number;
  final Ring ring;
  const CalTarget(this.number, this.ring);

  DartHit get hit => GranBoardDecoder.hitFor(number, ring);

  String get label => switch (ring) {
        Ring.singleInner => 'SIMPLE INTÉRIEUR $number',
        Ring.triple => 'TRIPLE $number',
        Ring.singleOuter => 'SIMPLE EXTÉRIEUR $number',
        Ring.double => 'DOUBLE $number',
        Ring.outerBull => 'BULL 25',
        Ring.innerBull => 'BULL 50 (CENTRE)',
      };
}

/// Les 82 zones, en tournant autour de la cible à partir du 20.
final List<CalTarget> kCalTargets = [
  for (final n in kBoardOrder) ...[
    CalTarget(n, Ring.singleInner),
    CalTarget(n, Ring.triple),
    CalTarget(n, Ring.singleOuter),
    CalTarget(n, Ring.double),
  ],
  const CalTarget(25, Ring.outerBull),
  const CalTarget(25, Ring.innerBull),
];

/// Calibration : on lance une fléchette dans chaque zone demandée,
/// l'appli enregistre la trame envoyée par la cible.
class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  final board = BoardService.instance;
  late final StreamSubscription<RawFrame> _sub;

  /// Trame enregistrée pour chaque zone (null = passée).
  final List<String?> _codes = [];

  /// Codes de la bordure extérieure (3s), enregistrés après les 82 zones.
  final List<String> _outCodes = [];
  String? _last;

  int get _index => _codes.length;
  bool get _done => _index >= kCalTargets.length;

  @override
  void initState() {
    super.initState();
    _sub = board.frames.listen(_onFrame);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onFrame(RawFrame f) {
    final key = GranBoardDecoder.frameKey(f.bytes);
    if (key == 'BTN@') return;
    setState(() => _last = key);
    final used = _codes.indexOf(key);
    if (_done) {
      // Étape bordure : chaque nouveau code compte comme « hors cible »
      if (used >= 0) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('Ce code est celui de ${kCalTargets[used].label}, '
                  'pas de la bordure.')));
      } else if (!_outCodes.contains(key)) {
        HapticFeedback.lightImpact();
        setState(() => _outCodes.add(key));
      }
      return;
    }
    if (_outCodes.contains(key)) return;
    if (used >= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Déjà enregistré pour ${kCalTargets[used].label}. '
                'Relance dans ${kCalTargets[_index].label}.')));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _codes.add(key));
  }

  void _skip() {
    if (_done) return;
    setState(() => _codes.add(null));
  }

  void _back() {
    if (_outCodes.isNotEmpty) {
      setState(() => _outCodes.removeLast());
      return;
    }
    if (_codes.isEmpty) return;
    setState(() => _codes.removeLast());
  }

  Map<String, DartHit?> get _table => {
        for (var i = 0; i < _codes.length; i++)
          if (_codes[i] != null) _codes[i]!: kCalTargets[i].hit,
        for (final c in _outCodes) c: null,
      };

  Future<void> _save() async {
    final table = _table;
    await board.saveCustomTable(table);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CALIBRATION ENREGISTRÉE', style: Tv.title(22)),
        content: Text('${table.length - _outCodes.length} zones'
            '${_outCodes.isEmpty ? '' : ' + ${_outCodes.length} code(s) de bordure'}'
            ' enregistrés pour cette cible.\n\n'
            'Tu peux copier la table pour l\'envoyer au développeur : '
            'elle sera intégrée pour ce modèle de cible.'),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: '# ${board.deviceName ?? 'GranBoard'}\n'
                      '${BoardTable.encode(table)}'));
              Navigator.pop(ctx);
            },
            child: const Text('Copier la table'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final target = _done ? null : kCalTargets[_index];
    final skipped = _codes.where((c) => c == null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('CALIBRATION')),
      body: ListenableBuilder(
        listenable: board,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!board.isConnected)
              Card(
                color: Tv.red.withValues(alpha: 0.25),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Connecte d\'abord la cible depuis l\'accueil.'),
                ),
              ),
            Text(
                'Lance une fléchette dans la zone indiquée. Le bouton de la '
                'cible n\'est pas pris en compte.',
                style: Tv.label(14, color: Tv.text)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                    '${_index.clamp(0, kCalTargets.length)} / ${kCalTargets.length}',
                    style: Tv.title(20, color: Tv.gold)),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _index / kCalTargets.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Dartboard(
                size: 250,
                highlights: target == null ? const [] : [target.hit],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                target == null
                    ? 'BORDURE EXTÉRIEURE'
                    : 'VISE : ${target.label}',
                textAlign: TextAlign.center,
                style: Tv.title(30, color: target == null ? Tv.gold : Tv.text),
              ),
            ),
            if (target == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Les 82 zones sont faites. Si ta cible a une bordure '
                  'détectée autour des doubles (GranBoard 3s), lance '
                  'plusieurs fléchettes tout autour dedans : elles compteront '
                  'comme ratées. Sinon, enregistre directement.\n'
                  '${_outCodes.length} code(s) de bordure enregistré(s).',
                  textAlign: TextAlign.center,
                  style: Tv.label(14, color: Tv.text),
                ),
              ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _last == null
                    ? 'En attente d\'une fléchette…'
                    : 'Reçu : "$_last"',
                style: Tv.label(13),
              ),
            ),
            if (skipped > 0)
              Center(
                child: Text('$skipped zone(s) passée(s)',
                    style: Tv.label(13, color: Tv.goldLight)),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed:
                        _codes.isEmpty && _outCodes.isEmpty ? null : _back,
                    icon: const Icon(Icons.undo),
                    label: const Text('RETOUR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: _done ? null : _skip,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('PASSER'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _table.isEmpty ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_done ? 'ENREGISTRER' : 'ENREGISTRER (PARTIEL)',
                  style: Tv.title(20, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
