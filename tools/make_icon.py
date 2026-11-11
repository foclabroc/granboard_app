"""Génère l'icône de l'appli (cible sur fond noir, anneau or).

Usage : python3 tools/make_icon.py   (nécessite Pillow)
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024
C = S / 2

BLACK = (18, 18, 22)
CREAM = (238, 226, 196)
RED = (200, 32, 40)
GREEN = (22, 140, 70)
GOLD = (232, 182, 60)
BG = (10, 10, 14)


def wedge(d, r_out, r_in, a0, a1, color):
    """Secteur d'anneau entre deux rayons et deux angles (degrés)."""
    pts = []
    steps = 12
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((C + r_out * math.cos(a), C + r_out * math.sin(a)))
    for i in range(steps, -1, -1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((C + r_in * math.cos(a), C + r_in * math.sin(a)))
    d.polygon(pts, fill=color)


def board():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=220, fill=BG)
    R = 430
    d.ellipse([C - R - 18, C - R - 18, C + R + 18, C + R + 18], fill=GOLD)
    d.ellipse([C - R, C - R, C + R, C + R], fill=BLACK)
    r_double_out, r_double_in = R * 0.86, R * 0.78
    r_triple_out, r_triple_in = R * 0.56, R * 0.48
    for i in range(20):
        a0 = -90 - 9 + i * 18
        a1 = a0 + 18
        even = i % 2 == 0
        single = BLACK if even else CREAM
        ring = RED if even else GREEN
        wedge(d, r_double_in, r_triple_out, a0, a1, single)
        wedge(d, r_triple_in, R * 0.12, a0, a1, single)
        wedge(d, r_double_out, r_double_in, a0, a1, ring)
        wedge(d, r_triple_out, r_triple_in, a0, a1, ring)
    rb = R * 0.12
    d.ellipse([C - rb, C - rb, C + rb, C + rb], fill=GREEN)
    rb2 = R * 0.055
    d.ellipse([C - rb2, C - rb2, C + rb2, C + rb2], fill=RED)
    # fils métalliques
    for i in range(20):
        a = math.radians(-90 - 9 + i * 18)
        d.line([(C + R * 0.12 * math.cos(a), C + R * 0.12 * math.sin(a)),
                (C + r_double_out * math.cos(a), C + r_double_out * math.sin(a))],
               fill=(150, 150, 150), width=4)
    for r in (r_double_out, r_double_in, r_triple_out, r_triple_in, R * 0.12):
        d.ellipse([C - r, C - r, C + r, C + r], outline=(150, 150, 150), width=4)
    return img


if __name__ == '__main__':
    img = board()
    sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144,
             'xxxhdpi': 192}
    for name, px in sizes.items():
        out = os.path.join(ROOT, f'android/app/src/main/res/mipmap-{name}',
                           'ic_launcher.png')
        img.resize((px, px), Image.LANCZOS).save(out)
        print(out)
    img.resize((512, 512), Image.LANCZOS).save(
        os.path.join(ROOT, 'assets/images/icon.png'))
