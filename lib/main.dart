import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ordre des zones a viser pendant la calibration.
final List<String> kTargets = [
  for (int n = 1; n <= 20; n++) ...[
    'S$n intérieur',
    'T$n',
    'S$n extérieur',
    'D$n',
  ],
  'Bull 25',
  'Bull 50',
  'Bouton',
];

const _prefsKey = 'granboard_mapping';

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
      home: const ScanPage(),
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

  @override
  Widget build(BuildContext context) {
    final sorted = [..._results]..sort((a, b) {
        final g = (_isGran(b) ? 1 : 0) - (_isGran(a) ? 1 : 0);
        return g != 0 ? g : b.rssi.compareTo(a.rssi);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('GranBoard – Scan')),
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
  final String source;
  final String hex;
  final String ascii;
  final String? label;
  LogEntry(this.time, this.source, this.hex, this.ascii, this.label);
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
  Map<String, String> _mapping = {};

  String _status = 'Connexion…';
  String? _lastHit;
  String? _lastRaw;

  bool _calibrating = false;
  int _calIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMapping();
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

  // ── Mapping (stockage local) ──

  Future<void> _loadMapping() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && mounted) {
      setState(() => _mapping = Map<String, String>.from(jsonDecode(raw)));
    }
  }

  Future<void> _saveMapping() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_mapping));
  }

  // ── BLE ──

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
        _info('SERVICE', s.uuid.str);
        for (final c in s.characteristics) {
          final p = c.properties;
          final props = [
            if (p.read) 'read',
            if (p.write) 'write',
            if (p.writeWithoutResponse) 'writeNR',
            if (p.notify) 'notify',
            if (p.indicate) 'indicate',
          ].join(',');
          _info('  CHAR', '${c.uuid.str}  [$props]');

          if (p.notify || p.indicate) {
            _subs.add(c.onValueReceived.listen((v) => _onData(c, v)));
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

  void _info(String source, String text) {
    if (!mounted) return;
    setState(() => _log.insert(0, LogEntry(DateTime.now(), source, text, '', null)));
  }

  void _onData(BluetoothCharacteristic c, List<int> v) {
    if (v.isEmpty || !mounted) return;

    final hex = v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final ascii =
        String.fromCharCodes(v.map((b) => (b >= 32 && b < 127) ? b : 46));

    String? label = _mapping[hex];

    if (_calibrating && _calIndex < kTargets.length) {
      label = kTargets[_calIndex];
      _mapping.removeWhere((_, t) => t == label); // évite les doublons
      _mapping[hex] = label;
      _calIndex++;
      if (_calIndex >= kTargets.length) _calibrating = false;
      _saveMapping();
    }

    HapticFeedback.lightImpact();
    setState(() {
      _lastHit = label ?? '?';
      _lastRaw = '$hex   |   "$ascii"';
      _log.insert(0, LogEntry(DateTime.now(), c.uuid.str, hex, ascii, label));
      if (_log.length > 400) _log.removeLast();
    });
  }

  // ── Calibration ──

  void _startCalibration() {
    final firstMissing =
        kTargets.indexWhere((t) => !_mapping.containsValue(t));
    setState(() {
      _calibrating = true;
      _calIndex = firstMissing == -1 ? 0 : firstMissing;
    });
  }

  void _skip() {
    setState(() {
      _calIndex++;
      if (_calIndex >= kTargets.length) _calibrating = false;
    });
  }

  Future<void> _export() async {
    final txt = const JsonEncoder.withIndent('  ').convert(_mapping);
    await Clipboard.setData(ClipboardData(text: txt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mapping copié (${_mapping.length} zones)')));
  }

  Future<void> _clearMapping() async {
    setState(() => _mapping = {});
    await _saveMapping();
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') _export();
              if (v == 'clearMap') _clearMapping();
              if (v == 'clearLog') setState(_log.clear);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Copier le mapping (JSON)')),
              PopupMenuItem(value: 'clearMap', child: Text('Effacer le mapping')),
              PopupMenuItem(value: 'clearLog', child: Text('Vider le log')),
            ],
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

          // Calibration
          Padding(
            padding: const EdgeInsets.all(12),
            child: _calibrating
                ? Card(
                    color: cs.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text('Vise : ${kTargets[_calIndex]}',
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                              value: _calIndex / kTargets.length),
                          Text('${_calIndex + 1} / ${kTargets.length}'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                  onPressed: _skip,
                                  child: const Text('Passer')),
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _calibrating = false),
                                  child: const Text('Arrêter')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _startCalibration,
                    icon: const Icon(Icons.tune),
                    label: Text(
                        'Calibrer (${_mapping.length}/${kTargets.length} zones)'),
                  ),
          ),

          const Divider(height: 1),

          // Log brut
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (_, i) {
                final e = _log[i];
                final t = e.time.toIso8601String().substring(11, 23);
                final isData = e.ascii.isNotEmpty;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Text(
                    isData
                        ? '$t  ${e.hex}  "${e.ascii}"  ${e.label ?? ''}'
                        : '$t  ${e.source}  ${e.hex}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isData ? null : cs.outline,
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
