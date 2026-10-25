"""Renders the RES-Q launcher icons and brand PNGs from the same geometry as
lib/ui/brand.dart (108-unit adaptive-icon grid). Supersampled for clean edges.

Usage: python -I scripts/brand/render_icons.py <repo_root>
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = sys.argv[1]
BLUE = (0x1A, 0x73, 0xE8)
BLUE_DEEP = (0x17, 0x4E, 0xA6)
BEACON = (0xFF, 0x6B, 0x5E)
WHITE = (255, 255, 255)
SS = 8  # supersampling factor


def gradient(size):
    """Diagonal blue gradient, top-left to bottom-right."""
    n = 256  # render small, then scale: a linear gradient survives resampling exactly
    img = Image.new('RGB', (n, n))
    px = img.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            px[x, y] = tuple(round(BLUE[i] + (BLUE_DEEP[i] - BLUE[i]) * t) for i in range(3))
    return img.resize((size, size), Image.BICUBIC)


def glyph(draw, scale, offset, unit):
    """Beacon pin: white location pin with a coral beacon, broadcasting radio arcs.

    Geometry (108-unit grid) is shared with lib/ui/brand.dart and the Android
    vector drawables.
    """
    import math

    def px(v):
        return (v - 54) * scale * unit + 54 * unit

    def py(v):
        return offset + (v - 54) * scale * unit + 54 * unit

    s = scale * unit
    cx, cy, r = px(54), py(47), 15 * s
    tip = (px(54), py(77))
    # Pin: circle head + tangent lines to the tip.
    d = (tip[1] - cy)
    theta = math.acos(r / d)
    t1 = (cx + r * math.sin(theta), cy + r * math.cos(theta))
    t2 = (cx - r * math.sin(theta), cy + r * math.cos(theta))
    draw.polygon([t1, tip, t2], fill=WHITE)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)
    # Beacon.
    b = 6.5 * s
    draw.ellipse([cx - b, cy - b, cx + b, cy + b], fill=BEACON)
    # Broadcast arcs either side of the pin head.
    w = 5 * s
    for radius, col in ((22 * s, WHITE), (29.5 * s, (0xB4, 0xCD, 0xF5))):
        box = [cx - radius, cy - radius, cx + radius, cy + radius]
        for a0, a1 in ((-38, 38), (142, 218)):
            draw.arc(box, a0, a1, fill=col, width=round(w))
            for a in (a0, a1):  # round caps
                ex = cx + (radius - w / 2) * math.cos(math.radians(a))
                ey = cy + (radius - w / 2) * math.sin(math.radians(a))
                draw.ellipse([ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2], fill=col)


def icon(px, corner_ratio=30 / 108, scale=1.12, glyph_center_shift=1.5):
    """Rounded-square app icon at px x px."""
    big = px * SS
    unit = big / 108
    tile = gradient(big).convert('RGBA')
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=round(big * corner_ratio), fill=255)
    tile.putalpha(mask)
    glyph(ImageDraw.Draw(tile, 'RGBA'), scale, glyph_center_shift * scale * unit, unit)
    return tile.resize((px, px), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print('wrote', os.path.relpath(path, ROOT), img.size)


# Legacy launcher icons (Android 7.x and below use these PNGs).
for folder, size in [('mipmap-mdpi', 48), ('mipmap-hdpi', 72), ('mipmap-xhdpi', 96), ('mipmap-xxhdpi', 144), ('mipmap-xxxhdpi', 192)]:
    img = icon(size)
    save(img, 'android', 'app', 'src', 'main', 'res', folder, 'ic_launcher.png')
    # Round variant: circular crop of the same tile.
    round_mask = Image.new('L', (size * SS, size * SS), 0)
    ImageDraw.Draw(round_mask).ellipse([0, 0, size * SS - 1, size * SS - 1], fill=255)
    rnd = icon(size, corner_ratio=0.5)
    save(rnd, 'android', 'app', 'src', 'main', 'res', folder, 'ic_launcher_round.png')

# Brand assets for README / store listing.
save(icon(512), 'assets', 'brand', 'resq_icon_512.png')
save(icon(192), 'assets', 'brand', 'resq_icon_192.png')
