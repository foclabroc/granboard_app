import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          notifyListeners();
        }
      }));

      final services = await d.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            _subs.add(c.onValueReceived.listen(_onData));
            await c.setNotifyValue(true);
          }
        }
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

  void _onData(List<int> bytes) {
    if (bytes.isEmpty) return;
    final e = GranBoardDecoder.decode(bytes);
    _frames.add(RawFrame(DateTime.now(), bytes, e));
    _events.add(e);
  }
}
