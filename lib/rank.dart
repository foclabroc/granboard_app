import 'package:flutter/material.dart';

/// Rangs façon GranBoard : note sur 20 lue dans le tableau des rangs (même
/// calcul que `gb__band` dans `sql/2026-11-12_rangs.sql`).

/// Seuil bas de chaque note (1 à 20) en PPR 01.
const kPprBounds = <double>[
  0, 35, 40, 45, 51, 57, 63, 69.5, 75.5, 82, //
  89, 96, 103, 110, 116, 122, 127, 132, 137, 142,
];

/// Seuil bas de chaque note (1 à 20) en MPR Cricket.
const kMprBounds = <double>[
  0, 1.20, 1.40, 1.60, 1.80, 2.00, 2.20, 2.45, 2.70, 3.00, //
  3.25, 3.50, 3.75, 4.00, 4.25, 4.50, 4.80, 5.10, 5.40, 5.70,
];

/// Note 1 à 20 (interpolée dans le palier) d'un PPR ou d'un MPR.
double bandRating(double v, List<double> lo) {
  if (v >= lo.last) return 20;
  for (var i = 0; i < 19; i++) {
    if (v < lo[i + 1]) {
      final r =
          i + 1 + (v.clamp(0, double.infinity) - lo[i]) / (lo[i + 1] - lo[i]);
      return (r * 100).round() / 100;
    }
  }
  return 20;
}

/// Un rang : lettres, première note du rang, couleur.
class Rank {
  final String label;
  final int from;
  final Color color;
  const Rank(this.label, this.from, this.color);
}

const kRanks = <Rank>[
  Rank('C', 1, Color(0xFF1EA7FF)),
  Rank('CC', 4, Color(0xFF1EA7FF)),
  Rank('B', 6, Color(0xFF19E26B)),
  Rank('BB', 8, Color(0xFF19E26B)),
  Rank('A', 10, Color(0xFFFF3D7F)),
  Rank('AA', 12, Color(0xFFFF3D7F)),
  Rank('S', 14, Color(0xFF4FB3D9)),
  Rank('SS', 16, Color(0xFF4FB3D9)),
  Rank('M', 18, Color(0xFFB0B4BE)),
  Rank('GM', 20, Color(0xFFE8C15A)),
];

/// Rang d'une note sur 20.
Rank rankOf(double rating) {
  var r = kRanks.first;
  for (final k in kRanks) {
    if (rating >= k.from) r = k;
  }
  return r;
}

/// Rang suivant (null au sommet).
Rank? nextRank(double rating) {
  for (final k in kRanks) {
    if (k.from > rating.floor()) return k;
  }
  return null;
}

/// Avancement dans le rang (0 à 1), pour l'anneau.
double rankProgress(double rating) {
  final r = rankOf(rating);
  final n = nextRank(rating);
  if (n == null) return 1;
  return ((rating - r.from) / (n.from - r.from)).clamp(0.0, 1.0);
}

/// Rang complet d'un joueur, tel que renvoyé par le serveur (`gb__grade`).
class Grade {
  final double? ppr;
  final double? mpr;
  final double? r01;
  final double? rcr;
  final double? rating;
  const Grade({this.ppr, this.mpr, this.r01, this.rcr, this.rating});

  static double? _d(Object? v) => (v as num?)?.toDouble();

  factory Grade.fromJson(Map<String, dynamic>? j) => j == null
      ? const Grade()
      : Grade(
          ppr: _d(j['ppr']),
          mpr: _d(j['mpr']),
          r01: _d(j['r01']),
          rcr: _d(j['rcr']),
          rating: _d(j['rating']));
}
