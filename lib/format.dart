/// Affichage à la française.
library;

extension FrNum on num {
  /// Nombre à [digits] décimales avec une virgule (« 6,00 »).
  String fr(int digits) => toStringAsFixed(digits).replaceAll('.', ',');
}

/// « 1 manche », « 3 manches » ([word] au singulier, [many] si le pluriel
/// n'est pas un simple « s »).
String plural(int n, String word, [String? many]) =>
    '$n ${n > 1 ? many ?? '${word}s' : word}';
