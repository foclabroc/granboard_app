import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'granboard.dart';
import 'update_check.dart';

void main() => runApp(const GranProtoApp());

class GranProtoApp extends StatelessWidget {
  const GranProtoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GranBoard Proto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: UpdateGate(key: updateGateKey, child: const ScanPage()),
    );
  }
}

// ───────────────────────────── SCAN ─────────────────────────────

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<ScanResult> _results = [];
  bool _scanning = false;
  late final StreamSubscription<List<ScanResult>> _resSub;
  late final StreamSubscription<bool> _scanSub;

  @override
  void initState() {
    super.initState();
    _resSub = FlutterBluePlus.scanResults.listen((r) {
      if (mounted) setState(() => _results = r);
    });
    _scanSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _scanning = s);
    });
  }

  @override
  void dispose() {
    _resSub.cancel();
    _scanSub.cancel();
    super.dispose();
  }

  String _name(ScanResult r) {
    final n = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : r.advertisementData.advName;
    return n.isEmpty ? '(sans nom)' : n;
  }

  bool _isGran(ScanResult r) => _name(r).toUpperCase().contains('GRAN');

  Future<void> _scan() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}
    }
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur scan : $e')));
    }
  }

  Future<void> _checkUpdate() async {
    final r = await updateGateKey.currentState?.check(manual: true);
    if (!mounted || r == 1) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r == 2
            ? 'Impossible de joindre GitHub'
            : 'À jour (v$kAppVersion)')));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._results]..sort((a, b) {
        final g = (_isGran(b) ? 1 : 0) - (_isGran(a) ? 1 : 0);
        return g != 0 ? g : b.rssi.compareTo(a.rssi);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('GranBoard – Scan'),
        actions: [
          IconButton(
            tooltip: 'Vérifier les mises à jour',
            icon: const Icon(Icons.system_update),
            onPressed: _checkUpdate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? FlutterBluePlus.stopScan : _scan,
        icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(_scanning ? 'Stop' : 'Scanner'),
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Allume la cible, ferme l\'appli GranBoard officielle, '
                  'puis appuie sur « Scanner ».',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final r = sorted[i];
                final gran = _isGran(r);
                return ListTile(
                  leading: Icon(gran ? Icons.adjust : Icons.bluetooth,
                      color: gran ? Colors.greenAccent : null),
                  title: Text(_name(r),
                      style: TextStyle(
                          fontWeight:
                              gran ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text('${r.device.remoteId.str}  •  ${r.rssi} dBm'),
                  onTap: () async {
                    await FlutterBluePlus.stopScan();
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              BoardPage(device: r.device, name: _name(r))),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ───────────────────────────── CIBLE ─────────────────────────────

class LogEntry {
  final DateTime time;
  final String text;
  final bool isData;
  LogEntry(this.time, this.text, {this.isData = true});
}

class BoardPage extends StatefulWidget {
  final BluetoothDevice device;
  final String name;
  const BoardPage({super.key, required this.device, required this.name});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final _subs = <StreamSubscription>[];
  final _log = <LogEntry>[];

  String _status = 'Connexion…';
  String? _lastHit;
  String? _lastRaw;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    widget.device.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      _subs.add(widget.device.connectionState.listen((s) {
        if (!mounted) return;
        if (s == BluetoothConnectionState.disconnected) {
          setState(() => _status = 'Déconnecté');
        }
      }));

      await widget.device
          .connect(timeout: const Duration(seconds: 15), autoConnect: false);

      final services = await widget.device.discoverServices();
      int listened = 0;

      for (final s in services) {
        _info('SERVICE ${s.uuid.str}');
        for (final c in s.characteristics) {
          final p = c.properties;
          final props = [
            if (p.read) 'read',
            if (p.write) 'write',
            if (p.writeWithoutResponse) 'writeNR',
            if (p.notify) 'notify',
            if (p.indicate) 'indicate',
          ].join(',');
          _info('  CHAR ${c.uuid.str}  [$props]');

          if (p.notify || p.indicate) {
            _subs.add(c.onValueReceived.listen(_onData));
            await c.setNotifyValue(true);
            listened++;
          }
        }
      }

      if (mounted) {
        setState(() => _status = 'Connecté – $listened canal(aux) écouté(s)');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Erreur : $e');
    }
  }

  void _info(String text) {
    if (!mounted) return;
    setState(() => _log.insert(0, LogEntry(DateTime.now(), text, isData: false)));
  }

  void _onData(List<int> v) {
    if (v.isEmpty || !mounted) return;

    final hex = v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final ascii =
        String.fromCharCodes(v.map((b) => (b >= 32 && b < 127) ? b : 46));
    final label = GranBoardDecoder.decode(v).label;

    HapticFeedback.lightImpact();
    setState(() {
      _lastHit = label;
      _lastRaw = '$hex   |   "$ascii"';
      _log.insert(0, LogEntry(DateTime.now(), '"$ascii"  →  $label'));
      if (_log.length > 400) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            tooltip: 'Vider le log',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(_log.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_status, style: TextStyle(color: cs.secondary)),
          ),

          // Dernier impact
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_lastHit ?? '—',
                      style: const TextStyle(
                          fontSize: 56, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_lastRaw ?? 'Lance une fléchette',
                      style: const TextStyle(fontFamily: 'monospace')),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Log
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (_, i) {
                final e = _log[i];
                final t = e.time.toIso8601String().substring(11, 23);
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Text(
                    '$t  ${e.text}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: e.isData ? null : cs.outline,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
