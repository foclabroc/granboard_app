#!/usr/bin/env python3
"""Ambiance et bruitages du jeu Zombies (synthétisés).
usage : python3 tools/motion_hits/zombie_sounds.py <dossier>"""
import subprocess, sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import make as m  # noqa: E402

OUT = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)


def save(name, x, stereo_q=4):
    x = x / (np.abs(x).max() + 1e-9) * .89
    wav = Path(f'/tmp/{name}.wav'); m.write_wav(wav, x)
    subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', str(wav), '-ac', '1',
                    '-ar', '44100', '-c:a', 'libvorbis', '-q:a', str(stereo_q), str(OUT / f'{name}.ogg')], check=True)
    print(name)


def lp(x, fc):
    spec = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / m.SR)
    return np.fft.irfft(spec / (1 + (f / fc) ** 4), len(x))


def bp(x, f0, q=1.5):
    spec = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / m.SR)
    return np.fft.irfft(spec * np.exp(-((np.log(f + 1) - np.log(f0)) ** 2) * q * 4), len(x))


# ── Ambiance en boucle (24 s) : vent, nappe grave qui respire, cloche lointaine, battement de cœur ──
m.set_dur(24.0); T = m.T; N = m.N
wind = bp(rng.standard_normal(N), 500, .6) * (0.5 + 0.5 * np.sin(2 * np.pi * T / 8) ** 2)
wind += bp(rng.standard_normal(N), 1400, 1.2) * .25 * (0.5 + 0.5 * np.sin(2 * np.pi * T / 6 + 1) ** 2)
drone = sum(np.sin(2 * np.pi * f * T + p) * a for f, p, a in [(55, 0, .5), (82.4, 1, .3), (110.6, 2, .15), (65.4, 3, .2)])
drone *= 0.6 + 0.4 * np.sin(2 * np.pi * T / 12)
dis = np.sin(2 * np.pi * 233 * T) * np.sin(2 * np.pi * 0.07 * T) * .05   # note qui grince
bells = sum(m.bell(t0, [196, 392, 588, 830], 3.5, .25) for t0 in (3.0, 15.0))
heart = np.zeros(N)
for t0 in np.arange(0.5, 24, 1.6):
    heart += m.kick(t0, 60, 35, .12, .5) + m.kick(t0 + .22, 55, 35, .1, .35)
amb = .5 * wind / np.abs(wind).max() + .35 * drone / np.abs(drone).max() + dis + .5 * bells + .25 * heart
# boucle sans couture : fondu croisé des 2 dernières secondes avec le début
fade = int(2 * m.SR); w = np.linspace(0, 1, fade)
amb[:fade] = amb[:fade] * w + amb[-fade:] * (1 - w)
save('zb_ambient', amb[:-fade], 3)

# ── Bruitages ──
m.set_dur(.6)
# éclatement de slime : coup mou + bruit humide qui décroît + « gloups »
x = m.kick(0, 140, 40, .15, .9) + lp(rng.standard_normal(m.N), 1800) * m.env(0, .002, .12) * 1.2
x += np.sin(2 * np.pi * np.cumsum(300 + 500 * np.exp(-m.T * 20)) / m.SR) * m.env(.04, .003, .08) * .4
save('zb_splat', x)
# os qui se brisent (squelette)
x = sum(bp(rng.standard_normal(m.N), 2500 + k * 700, 2) * m.env(k * .045, .001, .03) for k in range(5)) * 1.5
x += m.kick(0, 200, 80, .08, .5)
save('zb_bones', x)
# coup sur la barricade : bois qui craque
m.set_dur(.9)
x = m.kick(0, 90, 35, .3, 1.2) + lp(rng.standard_normal(m.N), 900) * m.env(0, .002, .2)
x += sum(bp(rng.standard_normal(m.N), 1200 + k * 300, 3) * m.env(.05 + k * .03, .001, .02) * .6 for k in range(6))
save('zb_barricade', x)
# nouvelle vague : gong grave + souffle qui monte
m.set_dur(2.4)
x = m.bell(0, [98, 147, 196, 262, 311], 2.2, .5) + m.whoosh(.0, .5, 3, 200, 2500, .3) + m.kick(0, 70, 30, .6, 1.0)
save('zb_wave', x)
# grognement de zombie (synthèse : voix grave rauque, voyelle « ouaah »)
m.set_dur(1.4)
f0 = 75 + 15 * np.sin(2 * np.pi * 2.3 * m.T) + rng.standard_normal(m.N).cumsum() * .002
src = np.sign(np.sin(2 * np.pi * np.cumsum(f0) / m.SR)) * .5 + rng.standard_normal(m.N) * .35
form = bp(src, 450, 3) + .7 * bp(src, 900, 3) + .3 * bp(src, 2300, 4)
x = form * np.clip(m.T / .15, 0, 1) * np.clip((1.4 - m.T) / .5, 0, 1) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * m.T))
save('zb_groan', x)
