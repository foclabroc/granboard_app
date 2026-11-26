#!/usr/bin/env python3
"""Vidéos en motion design avec son : coups (assets/hits/<style>_<coup>.mp4,
1,5 s) et récompenses d'une manche (assets/awards/<style>_<slug>.mp4, 4 s).

Images : render.html (canvas) dessinée image par image par Playwright.
Son : synthétisé ici (numpy), calé sur l'impact de chaque style.
usage : python3 tools/motion_hits/make.py <sortie> [hits|awards] [style ...]
        styles : impact neon gold (tous par défaut) ; sortie/hits et sortie/awards
Sortie : 960 × 540, 30 i/s, 1,5 s, H.264 Main 3.1, AAC 128k (comme les
vidéos d'avant, lues par la TV).
"""
import base64, os, shutil, subprocess, sys, tempfile, wave
from pathlib import Path

import numpy as np
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
FONT = HERE.parent.parent / 'assets/fonts/BarlowCondensed-ExtraBold.ttf'
SR, FPS = 44100, 30
HITS = ['t20', 'bull', 'dbull']
AWARDS = ['lowton', 'highton', 'ton80', 'hat_trick', '3_in_the_black', '3_in_a_bed', 'white_horse']
MARKS = {'hat_trick', '3_in_the_black', '3_in_a_bed', 'white_horse'}
# nom des fichiers : « neon » existe déjà dans assets/awards (ancienne vidéo)
OUTNAME = {'impact': 'impact', 'neon': 'synth', 'gold': 'gold'}
CROWD = HERE.parent.parent / 'assets/sounds/crowd.ogg'
DUR = 1.5
N = int(SR * DUR)
T = np.arange(N) / SR


def set_dur(d):
    global DUR, N, T
    DUR, N, T = d, int(SR * d), np.arange(int(SR * d)) / SR


def crowd():
    raw = subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-i', str(CROWD), '-f', 's16le', '-ac', '1',
                          '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, '<i2').astype(float) / 32768
    out = np.zeros(N)
    st = int(.35 * SR)
    n = min(len(x), N - st)
    out[st:st + n] = x[:n]
    return out / (np.abs(out).max() + 1e-9)


# ───────── briques de son ─────────
def rng(seed):
    return np.random.default_rng(seed)


def env(start, attack, decay, t=None):
    """Enveloppe : montée linéaire puis décroissance exponentielle."""
    t = T if t is None else t
    x = t - start
    e = np.where(x < 0, 0.0, np.where(x < attack, x / max(attack, 1e-4), np.exp(-(x - attack) / decay)))
    return e


def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandsweep(noise, f0, f1, t0, t1):
    """Bruit filtré dont la fréquence glisse de f0 à f1 (souffle)."""
    spec = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(len(noise), 1 / SR)
    out = np.zeros_like(noise)
    seg = 1024
    for s in range(0, len(noise), seg):
        tt = s / SR
        p = np.clip((tt - t0) / max(t1 - t0, 1e-3), 0, 1)
        fc = f0 * (f1 / f0) ** p
        w = np.exp(-((np.log(freqs + 1) - np.log(fc)) ** 2) / 0.35)
        chunk = np.fft.irfft(spec * w, len(noise))[s:s + seg]
        out[s:s + seg] = chunk
    return out / (np.abs(out).max() + 1e-9)


def kick(start, f0=120, f1=38, decay=.35, gain=1.0):
    x = T - start
    f = f1 + (f0 - f1) * np.exp(-np.clip(x, 0, None) * 18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return gain * np.sin(ph) * env(start, .002, decay)


def burst(start, seed, decay=.12, fc=3000, gain=.6):
    n = rng(seed).standard_normal(N)
    return gain * lowpass(n, fc) * env(start, .001, decay) * 3


def bell(start, freqs, decay=.5, gain=.3):
    s = np.zeros(N)
    for i, f in enumerate(freqs):
        s += np.sin(2 * np.pi * f * T) * env(start, .002, decay / (1 + i * .4)) / (1 + i * .3)
    return gain * s


def whoosh(t0, t1, seed, f0=300, f1=4000, gain=.5):
    n = rng(seed).standard_normal(N)
    w = bandsweep(n, f0, f1, t0, t1)
    e = np.clip((T - (t0 - .15)) / (t1 - t0 + .15), 0, 1) ** 2 * (T < t1 + .02)
    e = e + (T >= t1 + .02) * np.exp(-(T - t1) / .05)
    return gain * w * e


def saw(f, detune=0.0):
    ph = (T * f * (1 + detune)) % 1
    return 2 * ph - 1


def zap(start, f0=2400, f1=120, dur=.18, gain=.35):
    x = np.clip(T - start, 0, None)
    f = f1 + (f0 - f1) * np.exp(-x / (dur / 4))
    return gain * np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * env(start, .001, dur / 2)


def stab(start, notes, decay=.6, gain=.25, fc=2500):
    s = sum(saw(f, d) for f in notes for d in (-.004, .004))
    return gain * lowpass(s / (2 * len(notes)), fc) * env(start, .005, decay)


def finish(x):
    x = x - np.mean(x)
    x = np.tanh(x * 1.4) / np.tanh(1.4)               # limiteur doux
    x *= np.clip(1 - np.clip((T - (DUR - .15)) / .15, 0, 1), 0, 1)  # fondu final
    return x / (np.abs(x).max() + 1e-9) * .89


# ───────── son de chaque style ─────────
def sound(style, hit):
    seed = hash((style, hit)) & 0xffff
    deep = {'t20': 1.0, 'bull': .8, 'dbull': .7}[hit]
    s = np.zeros(N)
    if style == 'impact':
        t0 = .14
        s += whoosh(.0, t0, 1, 250, 5000, .45)
        s += kick(t0, 140 * deep, 40 * deep, .45, 1.2)
        s += burst(t0, 2, .16, 4000, .7)
        s += bell(t0 + .01, [1320 / deep, 1980 / deep, 2960 / deep], .5, .18)
        if hit == 'dbull':
            s += kick(t0 + .3, 150, 45, .4, 1.0) + burst(t0 + .3, 3, .12, 5000, .5)
        # petit tintement du compteur de points
        for k in range(6):
            s += bell(t0 + .2 + k * .07, [2400 + k * 120], .06, .07)
    elif style == 'neon':
        t0 = .16
        hum = (saw(60) + .5 * saw(120)) * .08 * np.clip((T - .05) / .1, 0, 1)
        flick = (rng(5).random(N // 600 + 1) > .4).repeat(600)[:N] * (T < .38) + (T >= .38)
        s += lowpass(hum, 900) * flick * (T < 1.3)
        s += zap(t0, 3000, 150, .22, .3)
        s += zap(t0 + .1, 2200, 200, .15, .2)
        base = {'t20': [220, 277, 330], 'bull': [196, 247, 294], 'dbull': [175, 220, 262, 349]}[hit]
        s += stab(.36, base, .7, .35, 3000)
        s += kick(.36, 110, 42, .35, .9)
        if hit == 'dbull':
            s += stab(.66, [b * 1.5 for b in base], .5, .25, 3500) + kick(.66, 110, 42, .3, .7)
    elif style == 'gold':
        s += whoosh(.0, .4, 7, 400, 3000, .3)
        for k in range(4):                         # médaille qui tourne
            s += bell(.08 + k * .08, [3100 + k * 90], .05, .06)
        s += kick(.42, 100 * deep, 35, .5, 1.0) + burst(.42, 8, .1, 2500, .4)
        s += bell(.42, [2093, 2637, 3136, 4186], .9, .22)   # « ching » de pièce
        s += bell(.7, [5274, 6272], .4, .12)                 # reflet
        for k in range(len({'t20': 'TRIPLE 20', 'bull': 'BULL', 'dbull': 'DOUBLE BULL'}[hit])):
            s += burst(.3 + k * .035 + .2, 20 + k, .03, 6000, .12)  # lettres qui tombent
        if hit == 'dbull':
            s += bell(.95, [2093 * 1.5, 3136 * 1.5], .5, .12)
    return finish(s)


def award_sound(style, key):
    """Récompense (4 s) : impact du style, puis 3 « pops » ou le compteur,
    sous-titre, et la foule qui applaudit en dessous."""
    s = np.zeros(N)
    big = key in ('ton80', '3_in_the_black')
    t0 = .3
    if style == 'impact':
        s += whoosh(.0, t0, 1, 200, 5000, .5)
        s += kick(t0, 130, 38, .55, 1.3) + burst(t0, 2, .2, 4000, .8)
        s += bell(t0 + .01, [990, 1485, 2220], .7, .18)
    elif style == 'neon':
        hum = (saw(60) + .5 * saw(120)) * .07 * np.clip((T - .05) / .1, 0, 1)
        s += lowpass(hum, 900) * (T < DUR - .3)
        s += zap(t0, 3000, 150, .25, .3) + zap(t0 + .1, 2200, 200, .15, .2)
        s += stab(.4, [220, 277, 330, 440], .9, .35, 3000) + kick(.4, 110, 42, .4, .9)
    else:
        s += whoosh(.0, .42, 7, 400, 3000, .3)
        for k in range(4):
            s += bell(.08 + k * .08, [3100 + k * 90], .05, .06)
        s += kick(.42, 100, 35, .6, 1.0) + bell(.42, [2093, 2637, 3136, 4186], 1.2, .22)
    if key in MARKS:                                   # 3 pastilles
        for i in range(3):
            tp = .8 + i * .32
            s += kick(tp, 160 + i * 30, 50, .25, .8) + burst(tp, 30 + i, .06, 5000, .35)
            s += bell(tp, [880 * (1.26 ** i), 1320 * (1.26 ** i)], .4, .16)
    else:                                              # compteur qui monte
        for k in range(18):
            tk = .7 + .9 * (1 - (1 - k / 18) ** 2)
            s += bell(tk, [1800 + k * 60], .04, .06)
        s += kick(1.6, 150, 45, .4, 1.0) + bell(1.6, [1568, 2093, 2637], .8, .2)
    s += bell(1.9, [1047, 1568], .6, .1) + whoosh(1.7, 1.95, 9, 1500, 6000, .15)  # sous-titre
    if big:
        s += stab(1.62, [196, 247, 294, 392], 1.2, .3, 2500)
    s += crowd() * (.55 if big else .4)
    return finish(s)


def write_wav(path, x):
    st = np.stack([x, x], 1)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((st * 32767).astype('<i2').tobytes())


def main():
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    args = sys.argv[2:]
    which = [a for a in args if a in ('hits', 'awards')] or ['hits', 'awards']
    styles = [a for a in args if a not in ('hits', 'awards')] or ['impact', 'neon', 'gold']
    work = Path(tempfile.mkdtemp())
    shutil.copy(HERE / 'render.html', work / 'render.html')
    shutil.copy(FONT, work / FONT.name)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={'width': 960, 'height': 540})
        pg.goto((work / 'render.html').as_uri())
        pg.evaluate('ready')
        jobs = [(st, h, 1.5, 'hits') for st in styles for h in HITS if 'hits' in which]
        jobs += [(st, a, 4.0, 'awards') for st in styles for a in AWARDS if 'awards' in which]
        for st, h, dur, kind in jobs:
            if True:
                set_dur(dur)
                (out / kind).mkdir(exist_ok=True)
                fr = work / f'{st}_{h}'; fr.mkdir()
                for i in range(int(DUR * FPS)):
                    url = pg.evaluate('([s, h, t]) => draw(s, h, t)', [st, h, i / FPS])
                    (fr / f'{i:03d}.png').write_bytes(base64.b64decode(url.split(',', 1)[1]))
                wav = work / f'{st}_{h}.wav'
                write_wav(wav, sound(st, h) if kind == 'hits' else award_sound(st, h))
                dst = out / kind / f'{OUTNAME[st]}_{h}.mp4'
                subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-framerate', str(FPS),
                                '-i', str(fr / '%03d.png'), '-i', str(wav),
                                '-c:v', 'libx264', '-preset', 'slow', '-crf', '22', '-maxrate', '2000k',
                                '-bufsize', '4000k', '-profile:v', 'main', '-level', '3.1', '-pix_fmt', 'yuv420p',
                                '-c:a', 'aac', '-b:a', '128k', '-t', str(DUR), '-movflags', '+faststart', str(dst)],
                               check=True)
                print(dst, os.path.getsize(dst) // 1024, 'Ko')
        b.close()
    shutil.rmtree(work)


if __name__ == '__main__':
    main()
