#!/usr/bin/env python3
"""Generates the launcher icon PNGs and the synthesized alarm sounds.

Usage (from the project root):  python3 tool/generate_assets.py
Requires: Pillow. Output is committed, so this only needs re-running when
the artwork or sounds should change.
"""
import math
import os
import struct
import wave

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

PURPLE = (155, 92, 255)
BLUE = (46, 196, 255)
NAVY = (11, 18, 38)
DEEP = (5, 7, 15)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient(size, c1, c2):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = lerp(c1, c2, (x + y) / (2.0 * size))
    return img


def star_points(cx, cy, outer, inner, points=4, rot=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = rot + i * math.pi / points
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def glow(layer, radius, strength=1.0):
    blurred = layer.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        r, g, b, a = blurred.split()
        a = a.point(lambda v: min(255, int(v * strength)))
        blurred = Image.merge("RGBA", (r, g, b, a))
    return blurred


def draw_artwork(size=1024):
    """Transparent-background artwork: glowing alarm clock with a nova star."""
    s = size
    c = s // 2
    art = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    grad = diagonal_gradient(s, PURPLE, BLUE).convert("RGBA")

    # Bells (two circles at the top corners) and feet.
    shapes = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(shapes)
    ring_r = int(s * 0.31)
    ring_w = int(s * 0.045)
    for sign in (-1, 1):
        bx = c + sign * int(ring_r * 0.82)
        by = c - int(ring_r * 0.86)
        br = int(s * 0.095)
        d.ellipse((bx - br, by - br, bx + br, by + br), fill=255)
        fx = c + sign * int(ring_r * 0.62)
        fy = c + int(ring_r * 0.98)
        d.line((fx, fy, fx + sign * int(s * 0.05), fy + int(s * 0.07)),
               fill=255, width=int(s * 0.035))
    # Main ring.
    d.ellipse((c - ring_r, c - ring_r, c + ring_r, c + ring_r), fill=255)
    inner = ring_r - ring_w
    d.ellipse((c - inner, c - inner, c + inner, c + inner), fill=0)
    clock = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    clock.paste(grad, (0, 0), shapes)

    # Neon glow under the ring.
    art = Image.alpha_composite(art, glow(clock, s * 0.035, 1.6))
    art = Image.alpha_composite(art, clock)

    # Nova star in the middle.
    star_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(star_layer)
    sd.polygon(star_points(c, c, s * 0.2, s * 0.045), fill=(235, 245, 255, 255))
    sd.polygon(star_points(c, c, s * 0.1, s * 0.03, rot=-math.pi / 4),
               fill=(190, 225, 255, 255))
    art = Image.alpha_composite(art, glow(star_layer, s * 0.05, 2.0))
    art = Image.alpha_composite(art, star_layer)
    dot = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse((c - s * 0.02, c - s * 0.02, c + s * 0.02, c + s * 0.02),
                                fill=(255, 255, 255, 255))
    art = Image.alpha_composite(art, dot)
    return art


def background(size=1024):
    s = size
    bg = Image.new("RGBA", (s, s), DEEP + (255,))
    px = bg.load()
    for y in range(s):
        for x in range(s):
            dx, dy = (x - s / 2) / (s / 2), (y - s / 2) / (s / 2)
            t = min(1.0, math.sqrt(dx * dx + dy * dy))
            px[x, y] = lerp(NAVY, DEEP, t) + (255,)
    haze = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    hd.ellipse((-s * 0.2, -s * 0.2, s * 0.6, s * 0.6), fill=PURPLE + (110,))
    hd.ellipse((s * 0.45, s * 0.5, s * 1.2, s * 1.2), fill=BLUE + (90,))
    return Image.alpha_composite(bg, haze.filter(ImageFilter.GaussianBlur(s * 0.12)))


def rounded_mask(size, radius_ratio=0.22):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1),
                                        radius=int(size * radius_ratio), fill=255)
    return m


def write_icons():
    art = draw_artwork(1024)
    full = Image.alpha_composite(background(1024), art)
    legacy = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    legacy.paste(full, (0, 0), rounded_mask(1024))

    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px in densities.items():
        d = os.path.join(RES, "mipmap-" + name)
        os.makedirs(d, exist_ok=True)
        legacy.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))

    # Adaptive foreground: artwork scaled into the 66dp safe zone of a 108dp canvas.
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    scaled = art.resize((int(1024 * 0.64), int(1024 * 0.64)), Image.LANCZOS)
    off = (1024 - scaled.size[0]) // 2
    fg.paste(scaled, (off, off), scaled)
    d = os.path.join(RES, "mipmap-xxxhdpi")
    fg.resize((432, 432), Image.LANCZOS).save(os.path.join(d, "ic_launcher_foreground.png"))
    # Preview used for review only (not part of the build).
    legacy.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "tool", "icon_preview.png"))


# ----------------------------- sounds ---------------------------------------
RATE = 22050


def write_wav(name, samples):
    d = os.path.join(RES, "raw")
    os.makedirs(d, exist_ok=True)
    peak = max(1e-9, max(abs(v) for v in samples))
    with wave.open(os.path.join(d, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v / peak * 0.85 * 32767)) for v in samples))


def tone(freq, dur, vol=1.0, harmonics=(1.0,), attack=0.01, release=0.08):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * min(1.0, (dur - t) / release)
        v = sum(h * math.sin(2 * math.pi * freq * (k + 1) * t) for k, h in enumerate(harmonics))
        out.append(v * env * vol)
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


def mix_seq(parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write_sounds():
    # Nova Pulse: pulsing synth beeps rising in pitch.
    seq = []
    for f in (660, 880, 1100, 880):
        seq += tone(f, 0.16, harmonics=(1.0, 0.35, 0.15)) + silence(0.07)
    seq += silence(0.35)
    write_wav("nova_pulse", seq * 3)

    # Aurora: soft rising arpeggio with a shimmer.
    seq = []
    for f in (523.25, 659.25, 783.99, 1046.5, 783.99, 659.25):
        seq += tone(f, 0.42, vol=0.9, harmonics=(1.0, 0.25), attack=0.03, release=0.3)
    seq += silence(0.5)
    write_wav("aurora", seq * 2)

    # Beacon: urgent double beep.
    seq = []
    for _ in range(2):
        seq += tone(1250, 0.12, harmonics=(1.0, 0.5, 0.3)) + silence(0.08)
        seq += tone(1250, 0.12, harmonics=(1.0, 0.5, 0.3)) + silence(0.45)
    write_wav("beacon", seq * 3)


if __name__ == "__main__":
    write_icons()
    write_sounds()
    print("assets generated")
