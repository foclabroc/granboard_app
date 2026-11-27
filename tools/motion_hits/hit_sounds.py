#!/usr/bin/env python3
"""Sons Pixabay (fournis par foclabroc) des vidéos motion design.

Remplace la piste son de assets/hits/<impact|synth|gold>_<t20|bull|dbull>.mp4
(1,5 s) et de assets/awards/<impact|synth|gold>_<slug>.mp4 (4 s : fanfare +
foule) sans refaire les images (vidéo copiée telle quelle). Chaque son est calé
pour que son attaque tombe sur l'impact du style, coupé à 1,5 s avec un
fondu de sortie, crête à -2 dB, sans limiteur ni loudnorm.
usage : python3 tools/motion_hits/hit_sounds.py
Aussi utilisé par make.py (son des coups).
"""
import subprocess, sys, tempfile, wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SRC = HERE / 'hit_sounds'
HITS_DIR = HERE.parent.parent / 'assets/hits'
AWARDS_DIR = HERE.parent.parent / 'assets/awards'
AWARDS = ['lowton', 'highton', 'ton80', 'hat_trick', '3_in_the_black', '3_in_a_bed', 'white_horse']
BIG = {'ton80', '3_in_the_black'}
# impact de l'image des récompenses (s) — voir award_sound() de make.py
IMPACT_AW = {'impact': .3, 'synth': .4, 'gold': .42}
SR, DUR, FADE = 44100, 1.5, .15
PEAK = 10 ** (-3 / 20)  # -3 dB avant AAC = environ -2 dB après

# impact de l'image de chaque style (s) — voir sound() de make.py
IMPACT = {'impact': .14, 'synth': .36, 'gold': .42}
# son choisi pour chaque vidéo
CHOICE = {
    ('impact', 't20'): 'sword', ('impact', 'bull'): 'whoosh_metal', ('impact', 'dbull'): 'winner_bell',
    ('synth', 't20'): 'power_up', ('synth', 'bull'): 'power_up', ('synth', 'dbull'): 'winner_bell',
    ('gold', 't20'): 'dagger', ('gold', 'bull'): 'dagger', ('gold', 'dbull'): 'winner_bell',
}


def load(name):
    raw = subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-i', str(SRC / f'{name}.mp3'),
                          '-f', 's16le', '-ac', '2', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, '<i2').astype(float).reshape(-1, 2) / 32768


def attack(x):
    """Début de l'attaque : 1re fenêtre de 10 ms à plus de la moitié de l'énergie max."""
    m = np.abs(x).max(1)
    w = SR // 100
    e = np.array([np.sqrt((m[i:i + w] ** 2).mean()) for i in range(0, len(m) - w, w)])
    return int(np.argmax(e > e.max() * .5)) * w


def place(x, shift, n):
    out = np.zeros((n, 2))
    if shift >= 0:
        k = min(len(x), n - shift)
        out[shift:shift + k] = x[:k]
    else:
        k = min(len(x) + shift, n)
        out[:k] = x[-shift:-shift + k]
    return out


def finish(out, dur, fade):
    t = np.arange(len(out)) / SR
    out = out * np.clip((dur - t) / fade, 0, 1)[:, None]
    return out / (np.abs(out).max() + 1e-9) * PEAK


def track(style, hit):
    x = load(CHOICE[(style, hit)])
    n = int(DUR * SR)
    return finish(place(x, int(IMPACT[style] * SR) - attack(x), n), DUR, FADE)


def award_track(style, key, dur=4.0):
    """Fanfare dont la 1re note tombe sur l'impact + foule en dessous dès 0,35 s."""
    n = int(dur * SR)
    fan = load('fanfare')
    fan = fan / (np.abs(fan).max() + 1e-9)
    crowd = load('crowd_cheer')
    crowd = crowd / (np.abs(crowd).max() + 1e-9)
    mix = place(fan, int(IMPACT_AW[style] * SR) - attack(fan), n)
    mix += place(crowd, int(.35 * SR), n) * (.5 if key in BIG else .35)
    return finish(mix, dur, .5)


def write_wav(path, x):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())


def main():
    tmp = Path(tempfile.mkdtemp())
    for (style, hit) in CHOICE:
        mp4 = HITS_DIR / f'{style}_{hit}.mp4'
        wav, out = tmp / f'{style}_{hit}.wav', tmp / mp4.name
        write_wav(wav, track(style, hit))
        subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', str(mp4), '-i', str(wav),
                        '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
                        '-t', str(DUR), '-movflags', '+faststart', str(out)], check=True)
        out.replace(mp4)
        print(mp4.name, CHOICE[(style, hit)])
    for style in IMPACT_AW:
        for key in AWARDS:
            mp4 = AWARDS_DIR / f'{style}_{key}.mp4'
            if not mp4.exists():
                continue
            wav, out = tmp / f'a_{style}_{key}.wav', tmp / mp4.name
            write_wav(wav, award_track(style, key))
            subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', str(mp4), '-i', str(wav),
                            '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
                            '-t', '4', '-movflags', '+faststart', str(out)], check=True)
            out.replace(mp4)
            print(mp4.name, 'fanfare + foule')


if __name__ == '__main__':
    sys.exit(main())
