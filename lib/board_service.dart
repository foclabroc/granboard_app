import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'board_lights.dart';
import 'granboard.dart';

enum BoardStatus { disconnected, connecting, connected }

/// Une trame brute reçue (pour l'écran de diagnostic).
class RawFrame {
  final DateTime time;
  final List<int> bytes;
  final BoardEvent event;
  RawFrame(this.time, this.bytes, this.event);

  String get hex =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  String get ascii =>
      String.fromCharCodes(bytes.map((b) => (b >= 32 && b < 127) ? b : 46));
}

/// Connexion à la cible, partagée par toute l'appli.
/// Les jeux écoutent [events] ; l'écran de diagnostic écoute [frames].
class BoardService extends ChangeNotifier {
  BoardService._();
  static final instance = BoardService._();

  static const _prefId = 'board_last_id';
  static const _prefName = 'board_last_name';
  static const _prefTable = 'board_table_'; // + identifiant de la cible

  /// Service de la GranBoard (3s) dont la caractéristique d'écriture reçoit
  /// les commandes des lumières.
  static const _ledService = '442f1570-8a00-9a28-cbe1-e1d4212d53eb';

  final _events = StreamController<BoardEvent>.broadcast();
  final _frames = StreamController<RawFrame>.broadcast();
  final _subs = <StreamSubscription>[];

  Stream<BoardEvent> get events => _events.stream;
  Stream<RawFrame> get frames => _frames.stream;

  BoardStatus status = BoardStatus.disconnected;
  BluetoothDevice? device;
  String? deviceName;
  String? error;

  /// Dernière cible utilisée (pour la reconnexion en un clic).
  String? lastId;
  String? lastName;

  bool get isConnected => status == BoardStatus.connected;

  /// Table calibrée de la cible connectée (null = table standard Dash).
  Map<String, DartHit?>? customTable;
  bool get hasCustomTable => customTable != null;

  Future<void> _loadTable(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefTable$id');
    customTable = raw == null ? null : BoardTable.decode(raw);
  }

  /// Enregistre la calibration pour la cible connectée (ou en mémoire seule).
  Future<void> saveCustomTable(Map<String, DartHit?>? table) async {
    customTable = table;
    final id = device?.remoteId.str ?? lastId;
    if (id != null) {
      final prefs = await SharedPreferences.getInstance();
      if (table == null) {
        await prefs.remove('$_prefTable$id');
      } else {
        await prefs.setString('$_prefTable$id', BoardTable.encode(table));
      }
    }
    notifyListeners();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    lastId = prefs.getString(_prefId);
    lastName = prefs.getString(_prefName);
    notifyListeners();
  }

  static Future<bool> ensureBluetooth() async {
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
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  /// Reconnexion à la dernière cible.
  Future<void> reconnect() async {
    final id = lastId;
    if (id == null) return;
    await connect(BluetoothDevice.fromId(id), name: lastName);
  }

  Future<void> connect(BluetoothDevice d, {String? name}) async {
    await disconnect();
    device = d;
    deviceName =
        name ?? (d.platformName.isEmpty ? 'GranBoard' : d.platformName);
    status = BoardStatus.connecting;
    error = null;
    notifyListeners();

    try {
      await ensureBluetooth();
      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);

      _subs.add(d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected &&
            status == BoardStatus.connected) {
          status = BoardStatus.disconnected;
          error = 'Cible déconnectée';
          BoardLights.instance.writer = null;
          notifyListeners();
        }
      }));

      final services = await d.discoverServices();
      BluetoothCharacteristic? writer;
      for (final s in services) {
        for (final c in s.characteristics) {
          // Écriture des lumières : celle du service GranBoard, sinon la
          // première d'un service non standard
          final canWrite =
              c.properties.write || c.properties.writeWithoutResponse;
          final id = s.uuid.str128.toLowerCase();
          if (canWrite &&
              (id == _ledService ||
                  (writer == null &&
                      !id.endsWith('-0000-1000-8000-00805f9b34fb')))) {
            writer = c;
          }
          if (c.properties.notify || c.properties.indicate) {
            _subs.add(c.onValueReceived.listen(_onData));
            await c.setNotifyValue(true);
          }
        }
      }

      await _loadTable(d.remoteId.str);
      final w = writer;
      if (w != null) {
        BoardLights.instance.writer = (bytes) => w.write(bytes,
            withoutResponse:
                w.properties.writeWithoutResponse && !w.properties.write);
        BoardLights.instance.connected();
      }
      status = BoardStatus.connected;
      lastId = d.remoteId.str;
      lastName = deviceName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefId, lastId!);
      await prefs.setString(_prefName, lastName!);
    } catch (e) {
      status = BoardStatus.disconnected;
      error = 'Connexion impossible : $e';
      try {
        await d.disconnect();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    BoardLights.instance.writer = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final d = device;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    status = BoardStatus.disconnected;
    notifyListeners();
  }

  /// Simule une trame reçue (tests et captures d'écran).
  @visibleForTesting
  void injectFrame(List<int> bytes) => _onData(bytes);

  void _onData(List<int> bytes) {
    if (bytes.isEmpty) return;
    final e = GranBoardDecoder.decode(bytes, custom: customTable);
    _frames.add(RawFrame(DateTime.now(), bytes, e));
    _events.add(e);
  }
}
