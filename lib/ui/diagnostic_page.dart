import 'dart:async';

import 'package:flutter/material.dart';

import '../board_service.dart';

/// Trames brutes reçues de la cible (pour déboguer).
class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  final _log = <RawFrame>[];
  late final StreamSubscription<RawFrame> _sub;

  @override
  void initState() {
    super.initState();
    _sub = BoardService.instance.frames.listen((f) {
      if (!mounted) return;
      setState(() {
        _log.insert(0, f);
        if (_log.length > 300) _log.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _log.isEmpty ? null : _log.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic'),
        actions: [
          IconButton(
            tooltip: 'Vider',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(_log.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(last?.event.label ?? '—',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold)),
                  Text(
                      last == null
                          ? 'Lance une fléchette'
                          : '${last.hex}   |   "${last.ascii}"',
                      style: const TextStyle(fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (_, i) {
                final f = _log[i];
                final t = f.time.toIso8601String().substring(11, 23);
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Text('$t  "${f.ascii}"  →  ${f.event.label}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
