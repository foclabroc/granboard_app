import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/x01.dart';

const kPlayerColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFFB8C00),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
];

/// Résumé d'une partie dans l'historique d'un joueur.
class GameRecord {
  final DateTime date;
  final String mode; // ex. « 501 » ou « Freeze 301 »
  final bool won;
  final double average;
  final int darts;
  final int? checkout;

  GameRecord({
    required this.date,
    required this.mode,
    required this.won,
    required this.average,
    required this.darts,
    this.checkout,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mode': mode,
        'won': won,
        'avg': average,
        'darts': darts,
        if (checkout != null) 'co': checkout,
      };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
        date: DateTime.parse(j['date'] as String),
        mode: j['mode'] as String,
        won: j['won'] as bool,
        average: (j['avg'] as num).toDouble(),
        darts: j['darts'] as int,
        checkout: j['co'] as int?,
      );
}

class PlayerProfile {
  final String id;
  String name;
  int colorIndex;

  // Statistiques X01 cumulées
  int games;
  int wins;
  int darts;
  int points;
  int bestCheckout;
  int highestTurn;
  int count180;
  int count100;
  List<GameRecord> history;

  PlayerProfile({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.games = 0,
    this.wins = 0,
    this.darts = 0,
    this.points = 0,
    this.bestCheckout = 0,
    this.highestTurn = 0,
    this.count180 = 0,
    this.count100 = 0,
    List<GameRecord>? history,
  }) : history = history ?? [];

  Color get color => kPlayerColors[colorIndex % kPlayerColors.length];
  double get average => darts == 0 ? 0 : points * 3 / darts;
  int get winRate => games == 0 ? 0 : (wins * 100 / games).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorIndex,
        'games': games,
        'wins': wins,
        'darts': darts,
        'points': points,
        'bestCo': bestCheckout,
        'high': highestTurn,
        'n180': count180,
        'n100': count100,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: j['color'] as int? ?? 0,
        games: j['games'] as int? ?? 0,
        wins: j['wins'] as int? ?? 0,
        darts: j['darts'] as int? ?? 0,
        points: j['points'] as int? ?? 0,
        bestCheckout: j['bestCo'] as int? ?? 0,
        highestTurn: j['high'] as int? ?? 0,
        count180: j['n180'] as int? ?? 0,
        count100: j['n100'] as int? ?? 0,
        history: [
          for (final h in (j['history'] as List? ?? const []))
            GameRecord.fromJson(h as Map<String, dynamic>)
        ],
      );
}

/// Profils enregistrés sur le téléphone.
class PlayerStore extends ChangeNotifier {
  PlayerStore._();
  static final instance = PlayerStore._();

  static const _key = 'players_v1';
  static const _historyMax = 50;

  final List<PlayerProfile> players = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    players.clear();
    if (raw != null) {
      try {
        for (final p in jsonDecode(raw) as List) {
          players.add(PlayerProfile.fromJson(p as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(players.map((p) => p.toJson()).toList()));
    notifyListeners();
  }

  PlayerProfile? byId(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<PlayerProfile> add(String name) async {
    final used = players.map((p) => p.colorIndex).toSet();
    var color = 0;
    while (used.contains(color) && color < kPlayerColors.length) {
      color++;
    }
    final p = PlayerProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      colorIndex: color % kPlayerColors.length,
    );
    players.add(p);
    await _save();
    return p;
  }

  Future<void> update(PlayerProfile p) => _save();

  Future<void> remove(PlayerProfile p) async {
    players.remove(p);
    await _save();
  }

  Future<void> resetStats(PlayerProfile p) async {
    p
      ..games = 0
      ..wins = 0
      ..darts = 0
      ..points = 0
      ..bestCheckout = 0
      ..highestTurn = 0
      ..count180 = 0
      ..count100 = 0
      ..history = [];
    await _save();
  }

  /// Enregistre une partie X01 terminée dans les profils des joueurs.
  Future<void> recordX01(X01Game g) async {
    final now = DateTime.now();
    for (var i = 0; i < g.players.length; i++) {
      final p = byId(g.players[i].id);
      if (p == null) continue;
      final s = g.stateOf(i);
      final won = g.winners.contains(i);
      p
        ..games += 1
        ..wins += won ? 1 : 0
        ..darts += s.darts
        ..points += s.points
        ..count180 += s.count180
        ..count100 += s.count100;
      if (s.highestTurn > p.highestTurn) p.highestTurn = s.highestTurn;
      final co = s.checkout;
      if (co != null && co > p.bestCheckout) p.bestCheckout = co;
      p.history.insert(
        0,
        GameRecord(
          date: now,
          mode: g.settings.name,
          won: won,
          average: s.average,
          darts: s.darts,
          checkout: co,
        ),
      );
      if (p.history.length > _historyMax) {
        p.history.removeRange(_historyMax, p.history.length);
      }
    }
    await _save();
  }
}
