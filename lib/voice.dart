/// Découpage des annonces de l'annonceur : la voix enregistrée
/// (`assets/voice/`, générée par `tools/make_voice.py`) dit tout ce qu'elle
/// connaît ; le reste (les pseudos) est lu par la synthèse vocale.
library;

/// Un morceau d'annonce : fichier de `assets/voice/` ou texte à synthétiser.
class VoicePart {
  final String? clip;
  final String? text;
  const VoicePart.clip(String this.clip) : text = null;
  const VoicePart.tts(String this.text) : clip = null;

  @override
  String toString() => clip != null ? '[$clip]' : '"$text"';
}

/// Mots d'un texte, comme dans `tools/make_voice.py` (`tokens`).
List<String> voiceTokens(String s) {
  s = s
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('÷', ' divisé par ')
      .replaceAll('×', ' fois ')
      .replaceAll('/', ' sur ')
      .replaceAll('+', ' plus ')
      .replaceAllMapped(
          RegExp(r'(^|[^0-9a-zà-ÿœ])-(?=[0-9])'), (m) => '${m[1]} moins ')
      .replaceAll('!', ' ! ')
      .replaceAll(RegExp(r"[^0-9a-zà-ÿœ'! ]"), ' ');
  return [
    for (final w in s.split(' '))
      if (w.isNotEmpty) w
  ];
}

class VoiceBank {
  /// Texte normalisé → fichier.
  final Map<String, String> index;
  final int _maxWords;

  VoiceBank(this.index)
      : _maxWords = index.keys
            .fold(1, (m, k) => k.split(' ').length > m ? k.split(' ').length : m);

  /// Annonces enregistrées qui couvrent tout [text], sinon null.
  List<String>? _cover(String text) {
    final words = voiceTokens(text);
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (words[i] == '!') {
        i++;
        continue;
      }
      var found = 0;
      for (var n = _maxWords; n > 0 && found == 0; n--) {
        if (i + n > words.length) continue;
        final w = words.sublist(i, i + n);
        if (w.last == '!' && n > 1 && index[w.join(' ')] == null) continue;
        final file = index[w.join(' ')] ??
            index[w.where((x) => x != '!').join(' ')];
        if (file != null) {
          out.add(file);
          found = n;
        }
      }
      if (found == 0) return null;
      i += found;
    }
    return out;
  }

  /// Découpe [text] : les [names] (pseudos) vont à la synthèse vocale, le
  /// reste à la voix enregistrée. Un passage qu'elle ne connaît pas en
  /// entier est lu d'un bloc par la synthèse vocale.
  List<VoicePart> plan(String text, [Iterable<String> names = const []]) {
    final list = names.where((n) => n.trim().isNotEmpty).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final parts = <VoicePart>[];
    void rest(String s) {
      if (!RegExp(r'[0-9a-zA-ZÀ-ÿœ]').hasMatch(s)) return;
      final clips = _cover(s);
      if (clips != null) {
        parts.addAll(clips.map(VoicePart.clip));
      } else {
        parts.add(VoicePart.tts(
            s.replaceAll(RegExp(r'^[\s,.:;!]+|[\s,:;]+$'), '')));
      }
    }

    if (list.isEmpty) {
      rest(text);
      return parts;
    }
    final re = RegExp(
        '(?<![0-9a-zA-ZÀ-ÿœ])(${list.map(RegExp.escape).join('|')})'
        '(?![0-9a-zA-ZÀ-ÿœ])',
        caseSensitive: false);
    var at = 0;
    for (final m in re.allMatches(text)) {
      rest(text.substring(at, m.start));
      parts.add(VoicePart.tts(m[0]!));
      at = m.end;
    }
    rest(text.substring(at));
    return parts;
  }
}
