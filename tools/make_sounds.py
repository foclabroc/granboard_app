"""Génère les bruitages et la musique de l'appli (100 % synthèse, libres de droits).

Usage : python3 tools/make_sounds.py   (nécessite numpy, scipy et ffmpeg)
Sortie : assets/sounds/*.ogg, assets/sounds/turn/*.ogg (sons du tour)
et assets/music/menu.ogg
"""

import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
RNG = np.random.default_rng(42)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, decay=0.2, sustain=0.0, release=0.0, total=None):
    """Enveloppe ADSR simple de longueur n échantillons."""
    a = int(SR * attack)
    d = int(SR * decay)
    r = int(SR * release)
    s = max(0, n - a - d - r)
    e = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0, r),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def lp(x, f, order=4):
    return sosfilt(butter(order, f, 'low', fs=SR, output='sos'), x)


def hp(x, f, order=4):
    return sosfilt(butter(order, f, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=4):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def saw(freq, tt):
    return 2 * ((tt * freq) % 1) - 1


def sine(freq, tt):
    return np.sin(2 * np.pi * freq * tt)


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, sec, total):
    out = np.zeros(int(SR * total))
    i = int(SR * sec)
    out[i:i + len(x)] += x[:len(out) - i]
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def save(x, path, quality=5):
    x = norm(x)
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix='.wav') as f:
        wavfile.write(f.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f.name,
                        '-c:a', 'libvorbis', '-q:a', str(quality), full],
                       check=True)
    print(path, f'{len(x) / SR:.2f}s')


# ─── Bruitages ───

def thud():
    """Impact de fléchette dans la cible."""
    n = int(SR * 0.18)
    tt = t(0.18)
    click = hp(RNG.normal(size=n), 2500) * env(n, 0.0005, 0.012)
    body = lp(RNG.normal(size=n), 900) * env(n, 0.001, 0.08) * 1.8
    low = sine(110 * np.exp(-tt * 8), tt) * env(n, 0.001, 0.12) * 1.2
    return mix(click * 0.6, body, low)


def chime(midis, step=0.07, length=0.5, bright=1.0):
    total = step * len(midis) + length
    parts = []
    for i, m in enumerate(midis):
        tt = t(length)
        f = note(m)
        tone = (sine(f, tt) + 0.4 * sine(2 * f, tt) * bright +
                0.15 * sine(3 * f, tt) * bright)
        parts.append(at(tone * env(len(tt), 0.002, length * 0.9), i * step,
                        total))
    return mix(*parts)


def bell(base=880, length=1.2):
    tt = t(length)
    ratios = [1, 2.76, 5.4, 8.93]
    amps = [1, 0.5, 0.3, 0.15]
    x = sum(a * sine(base * r, tt) * np.exp(-tt * (2 + 2 * k))
            for k, (r, a) in enumerate(zip(ratios, amps)))
    return x * env(len(tt), 0.001, length * 0.95)


def buzzer():
    tt = t(0.7)
    f = 230 * np.exp(-tt * 1.1)
    x = saw(f, tt) * (0.75 + 0.25 * np.sign(sine(14, tt)))
    return lp(x, 1800) * env(len(tt), 0.01, 0.25, 0.6, 0.2)


def whoosh():
    tt = t(0.4)
    x = RNG.normal(size=len(tt))
    # balayage du filtre en découpant en tranches
    out = np.zeros_like(x)
    chunks = 20
    size = len(x) // chunks
    for i in range(chunks):
        f = 500 + 4000 * np.sin(np.pi * i / chunks)
        seg = slice(i * size, (i + 1) * size)
        out[seg] = bp(x, f * 0.7, min(f * 1.4, 18000))[seg]
    return out * env(len(tt), 0.15, 0.25) * np.hanning(len(tt)) ** 0.3


def crowd(length=3.0, intensity=1.0):
    """Clameur de public (bruit filtré + applaudissements)."""
    n = int(SR * length)
    roar = bp(RNG.normal(size=n), 250, 2500)
    roar += 0.5 * bp(RNG.normal(size=n), 600, 4000)
    swell = env(n, 0.25, 0.4, 0.75, length * 0.45)
    claps = np.zeros(n)
    for _ in range(int(160 * length * intensity)):
        i = RNG.integers(0, n - 2000)
        c = hp(RNG.normal(size=900), 1200) * np.exp(-np.arange(900) / 120)
        claps[i:i + 900] += c * RNG.uniform(0.3, 1)
    claps *= env(n, 0.15, 0.3, 0.8, length * 0.5)
    whistle = sine(2300 + 120 * sine(5, t(0.6)), t(0.6)) * env(
        int(SR * 0.6), 0.03, 0.2, 0.6, 0.25) * 0.25
    return mix(roar * swell * 0.8, claps * 0.5, at(whistle, 0.4, length))


def brass(midi, length, vol=1.0):
    tt = t(length)
    f = note(midi)
    vib = 1 + 0.004 * sine(5.5, tt)
    x = saw(f * vib, tt) + 0.6 * saw(f * 1.003 * vib, tt)
    cutoff = 3500
    return lp(x, cutoff) * env(len(tt), 0.03, 0.1, 0.8, 0.15) * vol


def fanfare():
    total = 2.8
    seq = [(0.0, [60, 64, 67], 0.18), (0.2, [60, 64, 67], 0.18),
           (0.4, [60, 64, 67], 0.18), (0.6, [65, 69, 72], 0.45),
           (1.1, [67, 71, 74], 0.25), (1.4, [72, 76, 79, 84], 1.3)]
    parts = []
    for start, chord, ln in seq:
        for m in chord:
            parts.append(at(brass(m, ln, 0.5), start, total))
    timp = sine(55, t(0.6)) * np.exp(-t(0.6) * 6)
    parts.append(at(timp * 2, 1.4, total))
    return mix(*parts)


def ton():
    """Manche à 100+ : petite clameur courte."""
    return mix(crowd(1.6, 0.5) * 0.7, at(chime([72, 76, 79], 0.06, 0.4), 0.0,
                                          1.6) * 0.5)


# ─── Musique de menu (boucle 8 mesures, 110 bpm) ───

def music():
    bpm = 110
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    n = int(SR * total)
    out = np.zeros(n)

    def place(x, sec):
        i = int(SR * sec)
        j = min(n, i + len(x))
        out[i:j] += x[:j - i]

    # Am - F - C - G (deux fois)
    prog = [(57, [57, 60, 64]), (53, [53, 57, 60]), (48, [48, 52, 55]),
            (55, [55, 59, 62])] * 2

    for b, (root, chord) in enumerate(prog):
        bar = b * 4 * beat
        # nappe
        for m in chord:
            tt = t(4 * beat)
            pad = (saw(note(m + 12), tt) + saw(note(m + 12) * 1.005, tt))
            pad = lp(pad, 1400) * env(len(tt), 0.3, 0.5, 0.6, 0.6) * 0.07
            place(pad, bar)
        # basse en croches
        for k in range(8):
            tt = t(beat / 2 * 0.9)
            m = root - 12 + (12 if k in (3, 7) else 0)
            bass = lp(saw(note(m), tt), 600) * env(len(tt), 0.005, 0.15,
                                                    0.3, 0.05) * 0.35
            place(bass, bar + k * beat / 2)
        # batterie
        for k in range(4):
            tb = bar + k * beat
            kt = t(0.3)
            kick = sine(150 * np.exp(-kt * 25) + 45, kt) * np.exp(-kt * 9)
            place(kick * 0.9, tb)
            if k in (1, 3):
                st = int(SR * 0.25)
                snare = (bp(RNG.normal(size=st), 800, 6000) *
                         np.exp(-np.arange(st) / (SR * 0.05)))
                snare += sine(190, t(0.25)) * np.exp(-t(0.25) * 20) * 0.5
                place(snare * 0.45, tb)
            for h in range(2):
                ht = int(SR * 0.05)
                hat = hp(RNG.normal(size=ht), 7000) * np.exp(
                    -np.arange(ht) / (SR * 0.012))
                place(hat * (0.18 if h == 0 else 0.1), tb + h * beat / 2)
        # petite mélodie sur les mesures 5 à 8
        if b >= 4:
            mel = [chord[2] + 12, chord[1] + 12, chord[0] + 12, chord[1] + 12]
            for k, m in enumerate(mel):
                tt = t(beat * 0.8)
                lead = (np.sign(sine(note(m), tt)) * 0.5 + sine(note(m), tt))
                lead = lp(lead, 2500) * env(len(tt), 0.01, 0.2, 0.4,
                                             0.1) * 0.1
                place(lead, bar + k * beat)
    return out


# ─── Sons du tour (au choix de chaque joueur, 1 à 1,6 s) ───

def square(freq, tt):
    return np.sign(sine(freq, tt))


def turn_sounds():
    out = {}
    # Fanfare courte : ta-ta-taaa
    total = 1.4
    parts = []
    for start, m, ln in [(0, 67, 0.12), (0.14, 67, 0.12), (0.28, 72, 0.9)]:
        for k in (0, 4, 7):
            parts.append(at(brass(m + k, ln, 0.5), start, total))
    out['fanfare'] = mix(*parts)
    # Klaxon : deux coups
    tt = t(0.32)
    honk = lp(saw(370, tt) + saw(466, tt), 2200) * env(len(tt), 0.01, 0.05, 0.9, 0.05)
    out['klaxon'] = mix(at(honk, 0, 0.9), at(honk, 0.45, 0.9))
    # Laser : descente rapide
    tt = t(0.6)
    f = 2400 * np.exp(-tt * 6) + 200
    phase = 2 * np.pi * np.cumsum(f) / SR
    out['laser'] = np.sign(np.sin(phase)) * env(len(tt), 0.002, 0.55) * 0.6
    # Cloche : deux notes
    out['cloche'] = mix(bell(1318, 1.2), at(bell(988, 1.3), 0.25, 1.6))
    # Roulement de tambour + cymbale
    n = int(SR * 1.3)
    roll = np.zeros(n)
    for k in range(26):
        i = int(SR * 0.03 * k)
        st = int(SR * 0.06)
        hit = bp(RNG.normal(size=st), 300, 4000) * np.exp(-np.arange(st) / (SR * 0.02))
        roll[i:i + st] += hit * (0.3 + 0.7 * k / 26)
    cy = hp(RNG.normal(size=int(SR * 0.6)), 5000) * np.exp(-t(0.6) * 5)
    out['tambour'] = mix(roll, at(cy, 0.8, 1.4) * 0.8)
    # Guitare saturée : accord de quinte
    tt = t(1.2)
    g = sum(saw(note(m) * (1 + d), tt) for m in (40, 47, 52) for d in (0, 0.004))
    out['guitare'] = lp(np.tanh(g * 3), 3000) * env(len(tt), 0.005, 0.3, 0.5, 0.4)
    # Gong
    tt = t(1.6)
    gong = sum(a * sine(110 * r, tt) * np.exp(-tt * (1.2 + k))
               for k, (r, a) in enumerate(zip([1, 1.48, 2.1, 2.9, 3.7], [1, .7, .5, .35, .2])))
    out['gong'] = gong * (1 - np.exp(-tt * 80))
    # Sifflet d'arbitre
    tt = t(0.7)
    out['sifflet'] = (sine(2900 + 160 * sine(28, tt), tt) +
                      0.3 * bp(RNG.normal(size=len(tt)), 2500, 3500)) * env(len(tt), 0.02, 0.1, 0.8, 0.12)
    # Arpège de piano
    out['piano'] = chime([60, 64, 67, 72, 76], 0.09, 0.8, 0.6)
    # Arcade 8 bits : montée
    total = 0.9
    parts = []
    for i, m in enumerate([72, 76, 79, 84, 88]):
        tt = t(0.12)
        parts.append(at(square(note(m), tt) * env(len(tt), 0.001, 0.11) * 0.5, i * 0.08, total))
    out['arcade'] = mix(*parts)
    # Sonar
    out['sonar'] = mix(sine(1200, t(1.2)) * np.exp(-t(1.2) * 4),
                       at(sine(1200, t(0.8)) * np.exp(-t(0.8) * 6) * 0.3, 0.45, 1.3))
    # Coq
    tt = t(1.1)
    f = np.interp(tt, [0, .15, .35, .7, 1.1], [500, 900, 800, 1000, 600])
    phase = 2 * np.pi * np.cumsum(f) / SR
    crow = (np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase))
    out['coq'] = bp(crow * (1 + 0.4 * sine(40, tt)), 300, 4000) * env(len(tt), 0.03, 0.2, 0.7, 0.3)
    return out


if __name__ == '__main__':
    save(thud(), 'assets/sounds/hit.ogg')
    save(mix(thud(), at(chime([76, 83], 0.05, 0.45), 0.02, 0.6) * 0.45),
         'assets/sounds/double.ogg')
    save(mix(thud(), at(chime([72, 76, 79], 0.05, 0.45), 0.02, 0.7) * 0.5),
         'assets/sounds/triple.ogg')
    save(mix(thud(), at(bell(1046, 1.3), 0.02, 1.4) * 0.6),
         'assets/sounds/bull.ogg')
    save(buzzer(), 'assets/sounds/bust.ogg')
    save(whoosh(), 'assets/sounds/next.ogg')
    save(ton(), 'assets/sounds/ton.ogg')
    save(crowd(3.2, 1.2), 'assets/sounds/crowd.ogg')
    save(fanfare(), 'assets/sounds/win.ogg')
    save(music(), 'assets/music/menu.ogg', quality=4)
    for name, x in turn_sounds().items():
        save(x, f'assets/sounds/turn/{name}.ogg')
