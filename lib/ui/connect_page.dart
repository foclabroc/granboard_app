import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../board_service.dart';

/// Recherche des cibles Bluetooth à proximité.
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
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
    _scan();
  }

  @override
  void dispose() {
    _resSub.cancel();
    _scanSub.cancel();
    FlutterBluePlus.stopScan();
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
    await BoardService.ensureBluetooth();
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur de recherche : $e')));
    }
  }

  Future<void> _connect(ScanResult r) async {
    await FlutterBluePlus.stopScan();
    if (!mounted) return;
    Navigator.pop(context);
    await BoardService.instance.connect(r.device, name: _name(r));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._results]..sort((a, b) {
        final g = (_isGran(b) ? 1 : 0) - (_isGran(a) ? 1 : 0);
        return g != 0 ? g : b.rssi.compareTo(a.rssi);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir une cible'),
        bottom: _scanning
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: _scanning
          ? null
          : FloatingActionButton.extended(
              onPressed: _scan,
              icon: const Icon(Icons.refresh),
              label: const Text('Rechercher'),
            ),
      body: sorted.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Allume la cible et ferme l\'appli GranBoard officielle '
                  '(la cible n\'accepte qu\'une connexion).',
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
                  onTap: () => _connect(r),
                );
              },
            ),
    );
  }
}
