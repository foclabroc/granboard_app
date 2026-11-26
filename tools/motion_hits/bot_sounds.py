#!/usr/bin/env python3
"""Petit son du tour de chaque adversaire virtuel
(assets/sounds/turn/bot_<id>.ogg, < 1 s). usage :
python3 tools/motion_hits/bot_sounds.py"""
import subprocess, sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import make as m  # noqa: E402

OUT = Path(__file__).resolve().parent.parent.parent / 'assets/sounds/turn'


def tone(f, start, dur, kind='sine', gain=.3, glide=None):
    t = m.T - start
    ff = f if glide is None else f * (glide / f) ** np.clip(t / dur, 0, 1)
    ph = 2 * np.pi * np.cumsum(np.where(t >= 0, ff, 0)) / m.SR
    w = {'sine': np.sin(ph), 'square': np.sign(np.sin(ph)) * .6,
         'saw': 2 * ((ph / (2 * np.pi)) % 1) - 1, 'tri': 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1}[kind]
    return gain * w * m.env(start, .005, dur / 2.5) * (t < dur * 1.6)


def make(name, dur, s):
    x = m.finish(s)
    wav = Path(f'/tmp/{name}.wav')
    m.write_wav(wav, x)
    subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', str(wav), '-ac', '1',
                    '-af', 'loudnorm=I=-14', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '4',
                    str(OUT / f'{name}.ogg')], check=True)
    print(name)


m.set_dur(.9)
# Enzo : « bloup » qui hésite (monte puis retombe)
make('bot_enzo', .9, tone(300, 0, .25, 'sine', .5, 520) + tone(520, .25, .35, 'sine', .4, 260))
# Chloé : petit carillon doux de 2 notes
make('bot_chloe', .9, m.bell(0, [1568, 2350], .5, .3) + m.bell(.16, [2093, 3136], .6, .3))
# Nico : bouchon qui saute + verres
make('bot_nico', .9, tone(900, 0, .06, 'sine', .7, 250) + m.burst(0, 3, .03, 5000, .4)
     + m.bell(.18, [2637, 3951], .3, .2) + m.bell(.26, [2794, 4186], .3, .2))
# Karim : « wiz » qui glisse + claquement
make('bot_karim', .9, m.whoosh(0, .25, 4, 600, 6000, .5) + m.burst(.27, 5, .04, 6000, .6)
     + tone(220, .3, .2, 'saw', .2, 440))
# Antoine : trois tics réguliers puis « ding »
make('bot_antoine', .9, sum(tone(1200, k * .12, .04, 'square', .2) for k in range(3)) + m.bell(.38, [1760, 2640], .45, .3))
# Valérie : accord franc, montée
make('bot_valerie', .9, m.stab(0, [330, 415, 494], .25, .35, 3000) + m.stab(.16, [440, 554, 659], .45, .4, 3500))
# Gégé : vieille cloche de bar
make('bot_gege', .9, m.bell(0, [523, 1046, 1569, 2093], .9, .35) + m.bell(.3, [392, 784, 1176], .9, .3))
# Sarah : bips de machine
make('bot_sarah', .9, sum(tone(1800 + k * 400, k * .07, .05, 'square', .18) for k in range(5))
     + tone(3000, .4, .15, 'sine', .2, 1500))
# Le Boss : coup sourd + accord grave
make('bot_boss', .9, m.kick(0, 120, 35, .5, 1.2) + m.stab(.05, [98, 147, 196], .6, .4, 1800)
     + m.burst(0, 9, .08, 3000, .4))
