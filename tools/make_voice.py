#!/usr/bin/env python3
"""Génère les annonces de l'annonceur (assets/voice/) avec la voix Piper
« fr_FR-siwis-medium ».

  pip install piper-tts
  # voix : https://huggingface.co/rhasspy/piper-voices (fr/fr_FR/siwis/medium)
  python3 tools/make_voice.py /chemin/fr_FR-siwis-medium.onnx

Chaque annonce = un fichier mp3 + une entrée de index.json (clé = texte
normalisé comme dans lib/voice.dart : `voiceTokens`). L'appli découpe un
texte en annonces connues (la plus longue d'abord) ; ce qui reste (pseudos)
est lu par la synthèse vocale du téléphone.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import wave

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'voice')


def tokens(s):
    """Même découpage que `voiceTokens` (lib/voice.dart)."""
    s = s.lower().replace('’', "'")
    s = s.replace('÷', ' divisé par ').replace('×', ' fois ')
    s = s.replace('/', ' sur ').replace('+', ' plus ')
    s = re.sub(r'(?<![0-9a-zà-ÿœ])-(?=[0-9])', ' moins ', s)
    s = s.replace('!', ' ! ')
    s = re.sub(r"[^0-9a-zà-ÿœ'! ]", ' ', s)
    return s.split()


# Prononciation à la française des mots anglais (la voix est française)
SAY = {
    'bust': 'beust', 'bull': 'boul', 'white': 'ouaït', 'cut': 'keut',
    'throat': 'srôte', 'freeze': 'frîze', 'killer': 'kileur',
    'spoiler': 'spoïleur', 'shanghai': 'chan-gaï', 'spider': 'spaïdeur',
    'target': 'targuette', 'mickey': 'miki', 'mouse': 'maousse',
    'treasure': 'trèjeur', 'hunt': 'heunte', 'over': 'oveur',
    'down': 'daoune', 'count': 'caounte', 'up': 'eupe', 'half': 'hâf',
    'it': 'ite', 'fun': 'feune', 'shoot': 'choute', 'two': 'tou',
    'line': 'laïne', 'all': 'ôl', 'fives': 'faïve', 'beyond': 'biyonde',
    'wildcard': 'ouaïlde carde', 'only': 'onnli', 'team': 'time',
    'baseball': 'bèze bol', 'football': 'foute bol', 'birdie': 'beurdi',
    'hyper': 'hypère', "bob's": 'bobz', 'cr': 'cricket', 'hat': 'hate',
    'kick': 'kik', 'no': 'no', 'legs': 'lègue', 'leg': 'lègue',
    'oniren': 'onirène', 'delta': 'delta', 'combo': 'combo',
}

entries = {}  # clé → texte prononcé


def add(text, spoken=None):
    key = ' '.join(tokens(text))
    if not key or key in entries:
        return
    if spoken is None:
        # garde la ponctuation collée aux mots remplacés
        out = []
        for w in text.split():
            m = re.match(r"^([^.,!:]*)([.,!:]*)$", w)
            core, punct = (m.group(1), m.group(2)) if m else (w, '')
            out.append(SAY.get(core.lower(), core) + punct)
        spoken = ' '.join(out)
    if not re.search(r'[.!?,]$', spoken):
        spoken += '.'
    entries[key] = spoken


# ─── Nombres ───
for n in list(range(0, 181)) + list(range(200, 3001, 100)) + [301, 501, 701, 901]:
    add(str(n))
for n in range(100, 181):
    add(f'{n} !')
add('Cent quatre-vingts !')
for n in range(2, 171):
    add(f'il te reste {n}')
# Après les 3 fléchettes : ce qu'il reste à faire (01, Finition 121, Spider,
# Kick Down)
for n in range(1, 902):
    add(f'il reste {n}')

# ─── 01 ───
for t in ['Bust !', 'Bust ! Équipe gelée.', 'Aucun point', 'à toi',
          'ton équipe est gelée', 'spoiler', 'te défie']:
    add(t)
for n in (301, 501, 701, 901):
    add(f'Freeze {n}')

# ─── Cricket ───
add('Aucune marque')
add('Une marque')
for n in range(2, 10):
    add(f'{n} marques')
for n in range(5, 10):
    add(f'{n} marques !')
add('White horse !')
add('Hat trick !')
for n in list(range(1, 21)) + ['Bull']:
    add(f'{n} découvert !')
    add(f'Nouvelle cible : {str(n).lower()}')
    add(f'cible {n}')
    if n != 'Bull':
        add(f'cible double {n}')
        add(f'cible triple {n}')
        add(f'double {n}')
        add(f'triple {n}')
add('cible double bull')
for v in ['Cricket', 'Cut Throat', 'Cricket caché', 'Cut Throat caché',
          'Wildcard', 'No Score', 'Triple Only', 'Mickey Mouse']:
    add(v)
    add(f'Team {v}')

# ─── Fin de leg, de partie ───
add('Partie gagnée ! Victoire de', 'Partie gagnée ! Victoire de,')
add('Fin de la partie. Victoire de', 'Fin de la partie. Victoire de,')
add('Jeu, set et match ! Victoire de', 'Jeu, sète et match ! Victoire de,')
add('Objectif atteint ! Victoire de', 'Objectif atteint ! Victoire de,')
add("Fin de l'entraînement. Score :", "Fin de l'entraînement. Score,")
add('Leg pour', 'Lègue pour,')
add('et', 'et,')
add('à', 'à,')
add('Équipe A :', 'Équipe A,')
add('Équipe B :', 'Équipe B,')
for a in range(0, 8):
    for b in range(0, 8):
        add(f'{a} à {b}')
for n in range(3, 14):
    add(f'Match en {n} legs. Leg 1,', f'Match en {n} lègue. Lègue 1,')
for n in range(1, 14):
    add(f'Leg {n},', f'Lègue {n},')

# ─── Entraînement et fête ───
for g in ['Count Up', 'Target 20', 'Target Bull', 'Choix de cible',
          'Target Hat', 'Target Horse', 'Half It', 'Delta Shoot', 'Rotation',
          'Shoot Force', 'Oniren', 'CR Count Up', 'CR Multiple', "Bob's 27",
          'Finition 121', 'Spider', 'Pirates', 'Fun Mission', 'All Fives',
          'Beyond Top', 'Kick Down', 'Two Line', 'Shanghai', 'Hyper Bull',
          'Cache-cache', 'Killer', 'Treasure Hunt', 'Morpion', 'Baseball',
          'Golf', 'Scram', 'Football', 'Patate chaude']:
    add(g)
for t in [
    # mots de liaison
    'cible', 'double', 'triple', 'bull', 'plus', 'moins', 'divisé par 2',
    'divisé par deux', 'bonus', 'combo', 'réussi', 'raté', 'pris', 'repris !',
    'libéré', 'inversé', 'sur', 'éliminé', 'éliminé !', 'est killer !', 'à 0 !',
    'trop !', 'rien', 'ou',
    # cibles
    'tout compte', '3 triples 15 20', 'doubles', 'triples',
    'double ou triple', 'double bull', '15 20 ou bull', 'chance au trésor',
    'un triple', 'un double', 'le bull', '60 points ou plus',
    '3 numéros différents', '2 fois le même numéro', 'un total de 40 à 60',
    'total multiple de 5', 'prends des numéros', 'le plus près du centre',
    'ouvre une fenêtre', 'killer : vise les autres', 'trésors fois 2',
    'effets inversés', 'creuse un numéro', 'prends une case',
    'ferme les numéros', 'marque sur les ouverts', 'marque : un double',
    'prends le ballon : bull', 'finir', 'plus de', 'atteindre', 'araignée',
    'navire',
    # notes de manche
    'white horse', 'hat trick', 'bust', '3 triples plus 3000', 'validé',
    'vie perdue', 'araignée abattue', 'toutes abattues', 'navire 1 coulé !',
    'navire 2 coulé !', 'navire 3 coulé !', 'trésor vitesse',
    'mission réussie', 'mission ratée', 'mission réussie : plus 1 vie',
    'pas un multiple de 5', 'battu !', 'pas battu : moins 1 vie',
    'over score', 'kick down', 'numéros mélangés !', 'shanghai !',
    'un méchant de plus !', 'animal trouvé', 'le méchant !',
    'rien touché : divisé par 2', '3 animaux : plus 200',
    'aucun animal : moins 100', 'aïe, ton propre numéro !',
    'crâne du bull : tour passé', 'bouclier', 'bouclier !', 'diamant',
    "lingot d'or fois 2", 'lingot inversé divisé par 2', 'crâne blanc',
    'crâne violet', 'crâne rouge', 'grenade', 'couteau', 'épée', 'coffre',
    'coffres', 'alignée !', 'aligné !', 'tout fermé : on échange !',
    'birdie : 1 coup', 'par : 2 coups', '3 coups', 'raté : 5 coups', 'case',
    'prise',
]:
    add(t)


# ─── Commentaires de l'annonceur (v0.6.6) ───
add('raté')
add('25')
add('Match point')
add('Fin à', 'Fin à,')
add('Plus haute fin de la soirée')
add('plus que', 'plus que,')
for i, o in enumerate(['Deuxième', 'Troisième', 'Quatrième', 'Cinquième',
                       'Sixième', 'Septième', 'Huitième', 'Neuvième',
                       'Dixième'], start=2):
    add(f'{o} 180 de la soirée', f'{o} cent quatre-vingts de la soirée !')
add('Encore un 180', 'Encore un cent quatre-vingts !')

# ─── Chambrage (v0.6.6, lib/ui/game_fx.dart kLowTeases / kBustTeases /
# kZeroMarkTeases : mêmes textes) ───
TEASES = [
    'Aïe, c\'est maigre.',
    'On a connu mieux.',
    'Il fait froid aux doigts ?',
    'Les fléchettes sont dans le bon sens ?',
    'Allez, on se réveille !',
    'C\'était un échauffement, j\'espère.',
    'La cible, c\'est un peu plus haut.',
    'Petit tour pour rien.',
    'Trop gourmand !',
    'Il fallait freiner !',
    'Calcul mental à revoir.',
    'La prochaine fois, on compte sur ses doigts.',
    'Zéro marque, on se concentre !',
    'Le Cricket, c\'est pas du hasard.',
    'Les numéros ne vont pas se fermer tout seuls.',
]
for t in TEASES:
    add(t)
# Bowling, Paint
add('strike !', 'Straïke !')
add('spare !', 'Spère !')
add('zone prise')
add('protégée')


def main():
    # --add : ne fabrique que les annonces absentes de index.json (les
    # fichiers existants ne bougent pas)
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    only_new = '--add' in sys.argv
    model = [a for a in sys.argv[1:] if a != '--add'][0]
    from piper import PiperVoice
    voice = PiperVoice.load(model)
    os.makedirs(OUT, exist_ok=True)
    index = {}
    if only_new:
        with open(os.path.join(OUT, 'index.json'), encoding='utf-8') as f:
            index = json.load(f)
    else:
        for f in os.listdir(OUT):
            os.remove(os.path.join(OUT, f))
    used = set(index.values())
    tmp = tempfile.mkdtemp()
    i = 0
    for key, spoken in sorted(entries.items()):
        if key in index:
            continue
        while f'{i:04d}.mp3' in used:
            i += 1
        name = f'{i:04d}.mp3'
        used.add(name)
        wav = os.path.join(tmp, 'a.wav')
        with wave.open(wav, 'wb') as w:
            voice.synthesize_wav(spoken, w)
        # silences coupés (les annonces s'enchaînent), niveau égalisé
        subprocess.run([
            'ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-af',
            'silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
            'silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
            'apad=pad_dur=0.06,dynaudnorm=p=0.9:f=200,volume=-1dB',
            '-ac', '1', '-ar', '22050', '-c:a', 'libmp3lame', '-b:a', '40k',
            '-write_xing', '0', '-id3v2_version', '0',
            os.path.join(OUT, name)
        ], check=True)
        index[key] = name
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, separators=(',', ':'))
    print(len(index), 'annonces')


if __name__ == '__main__':
    main()
