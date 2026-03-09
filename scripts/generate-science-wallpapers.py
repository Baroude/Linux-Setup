#!/usr/bin/env python3
"""
Catppuccin science wallpaper generator.
Generates 3840x2160 (or 1920x1080 preview) wallpapers for:
  constellation, orbital, aminoacid, feynman

Usage:
  python3 generate-science-wallpapers.py                     # all types
  python3 generate-science-wallpapers.py --type constellation
  python3 generate-science-wallpapers.py --type constellation --name orion
  python3 generate-science-wallpapers.py --preview           # 1920x1080
"""

import matplotlib
matplotlib.use("Agg")

import argparse
import os
import io
import sys
import math
import random
import hashlib

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ─────────────────────────────────────────────
# Catppuccin Mocha palette
# ─────────────────────────────────────────────
CAT = {
    "base":      "#1e1e2e",
    "rosewater": "#f5e0dc",
    "flamingo":  "#f2cdcd",
    "pink":      "#f5c2e7",
    "mauve":     "#cba6f7",
    "red":       "#f38ba8",
    "maroon":    "#eba0ac",
    "peach":     "#fab387",
    "yellow":    "#f9e2af",
    "green":     "#a6e3a1",
    "teal":      "#94e2d5",
    "sky":       "#89dceb",
    "sapphire":  "#74c7ec",
    "blue":      "#89b4fa",
    "lavender":  "#b4befe",
    "text":      "#cdd6f4",
    "subtext1":  "#bac2de",
}

BG_HEX = CAT["base"]

FULL_W,    FULL_H    = 3840, 2160
PREVIEW_W, PREVIEW_H = 1920, 1080

OUT_DIR = r"C:\Users\Mathias\Documents\Linux-Setup\images\wallpaper-rotation\catppuccin"

# ─────────────────────────────────────────────
# Font helpers
# ─────────────────────────────────────────────
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\segoeuil.ttf",
    r"C:\Windows\Fonts\segoeuisl.ttf",
    r"C:\Windows\Fonts\segoeui.ttf",
    r"C:\Windows\Fonts\arial.ttf",
    r"C:\Windows\Fonts\calibri.ttf",
]

def get_font(size: int) -> ImageFont.FreeTypeFont:
    for fc in FONT_CANDIDATES:
        if os.path.exists(fc):
            try:
                return ImageFont.truetype(fc, size)
            except Exception:
                pass
    return ImageFont.load_default()

def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def hex_to_rgb01(h: str) -> tuple:
    r, g, b = hex_to_rgb(h)
    return (r / 255, g / 255, b / 255)

# ─────────────────────────────────────────────
# Shared: add name label to canvas via PIL
# ─────────────────────────────────────────────
def add_label(canvas: Image.Image, label: str, accent_hex: str,
              center_x: int, top_y: int) -> None:
    """Draw `label` text centered at center_x, starting at top_y."""
    draw = ImageDraw.Draw(canvas)
    W, H = canvas.size
    font_size = int(H * 0.025)
    font = get_font(font_size)
    color = hex_to_rgb(accent_hex)
    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    tx = center_x - tw // 2
    draw.text((tx, top_y), label, fill=color, font=font)

# ─────────────────────────────────────────────
# Shared: render matplotlib figure to PIL image
# ─────────────────────────────────────────────
def fig_to_pil(fig) -> Image.Image:
    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches="tight", pad_inches=0)
    buf.seek(0)
    return Image.open(buf).convert("RGBA")

def make_mpl_canvas(W: int, H: int, dpi: int = 100) -> tuple:
    """Returns (fig, ax) sized exactly W×H pixels."""
    fig, ax = plt.subplots(figsize=(W / dpi, H / dpi), dpi=dpi)
    fig.patch.set_facecolor(BG_HEX)
    ax.set_facecolor(BG_HEX)
    ax.set_aspect("equal")
    ax.axis("off")
    return fig, ax

def glow_dot(ax, x, y, base_ms, accent_hex, accent01, zorder=4):
    """Draw a dot with soft glow by stacking translucent circles."""
    for mult, alpha in [(3.5, 0.06), (2.5, 0.10), (1.7, 0.18), (1.0, 0.90)]:
        ax.plot(x, y, "o", color=accent_hex, markersize=base_ms * mult,
                alpha=alpha, zorder=zorder, markeredgewidth=0)


# ─────────────────────────────────────────────
# Visual effects helpers
# ─────────────────────────────────────────────

def apply_vignette(canvas: Image.Image, strength: float = 0.25) -> Image.Image:
    """Radial darkening from center to edges using Catppuccin crust color."""
    W, H = canvas.size
    cx, cy = W / 2, H / 2
    max_r = math.sqrt(cx ** 2 + cy ** 2)
    y_idx, x_idx = np.mgrid[0:H, 0:W]
    dist = np.sqrt((x_idx - cx) ** 2 + (y_idx - cy) ** 2)
    norm = np.clip(dist / max_r, 0, 1)
    alpha = (norm ** 2 * strength * 255).astype(np.uint8)
    cr, cg, cb = hex_to_rgb("#11111b")
    overlay = np.zeros((H, W, 4), dtype=np.uint8)
    overlay[:, :, 0] = cr; overlay[:, :, 1] = cg; overlay[:, :, 2] = cb
    overlay[:, :, 3] = alpha
    result = Image.alpha_composite(canvas.convert("RGBA"),
                                   Image.fromarray(overlay, "RGBA"))
    return result.convert("RGB")


def apply_glow_bloom(canvas: Image.Image, accent_hex: str,
                     blur_radius: int = None, opacity: float = 0.30) -> Image.Image:
    """Additive glow: blur canvas, tint toward accent, composite back."""
    W, H = canvas.size
    if blur_radius is None:
        blur_radius = max(20, int(80 * W / 3840))
    blurred = canvas.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    ar, ag, ab = hex_to_rgb(accent_hex)
    accent_img = Image.new("RGB", canvas.size, (ar, ag, ab))
    tinted = Image.blend(blurred, accent_img, alpha=0.25)
    c_arr = np.array(canvas, dtype=float) / 255
    t_arr = np.array(tinted, dtype=float) / 255
    result = np.clip(c_arr + t_arr * opacity, 0, 1)
    return Image.fromarray((result * 255).astype(np.uint8))


def draw_star_field(canvas: Image.Image, accent_hex: str,
                    seed: int, n_stars: int = 300) -> Image.Image:
    """Scatter faint accent-colored star dots across the canvas."""
    W, H = canvas.size
    rng = random.Random(seed)
    ar, ag, ab = hex_to_rgb(accent_hex)
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for _ in range(n_stars):
        sx = int(rng.random() * W)
        sy = int(rng.random() * H)
        alpha = int(rng.uniform(15, 50))
        ri = max(1, int(rng.uniform(0.5, 2.0)))
        draw.ellipse([sx - ri, sy - ri, sx + ri, sy + ri],
                     fill=(ar, ag, ab, alpha))
    result = Image.alpha_composite(canvas.convert("RGBA"), overlay)
    return result.convert("RGB")


def draw_center_haze(canvas: Image.Image, accent_hex: str,
                     opacity: float = 0.12, radius_frac: float = 0.35) -> Image.Image:
    """Soft radial accent glow at canvas center, fading to transparent."""
    W, H = canvas.size
    cx, cy = W / 2, H / 2
    max_r = min(W, H) * radius_frac
    y_idx, x_idx = np.mgrid[0:H, 0:W]
    dist = np.sqrt((x_idx - cx) ** 2 + (y_idx - cy) ** 2)
    norm = np.clip(dist / max_r, 0, 1)
    alpha = ((1 - norm) ** 2 * opacity * 255).astype(np.uint8)
    ar, ag, ab = hex_to_rgb(accent_hex)
    overlay = np.zeros((H, W, 4), dtype=np.uint8)
    overlay[:, :, 0] = ar; overlay[:, :, 1] = ag; overlay[:, :, 2] = ab
    overlay[:, :, 3] = alpha
    result = Image.alpha_composite(canvas.convert("RGBA"),
                                   Image.fromarray(overlay, "RGBA"))
    return result.convert("RGB")


# ─────────────────────────────────────────────────────────────────────────────
# TYPE 1: Constellations
# ─────────────────────────────────────────────────────────────────────────────
CONSTELLATIONS = {
    "orion": {
        "stars": {
            "Betelgeuse": (0.35, 0.68, 0.9),
            "Bellatrix":  (0.60, 0.70, 0.6),
            "Mintaka":    (0.455, 0.505, 0.5),
            "Alnilam":    (0.500, 0.500, 0.55),
            "Alnitak":    (0.545, 0.490, 0.5),
            "Saiph":      (0.38, 0.28, 0.6),
            "Rigel":      (0.63, 0.26, 0.95),
            "Meissa":     (0.50, 0.88, 0.5),
        },
        "lines": [
            ("Betelgeuse","Bellatrix"),("Betelgeuse","Mintaka"),("Bellatrix","Mintaka"),
            ("Mintaka","Alnilam"),("Alnilam","Alnitak"),
            ("Betelgeuse","Saiph"),("Bellatrix","Rigel"),
            ("Saiph","Alnitak"),("Betelgeuse","Meissa"),("Bellatrix","Meissa"),
        ],
    },
    "ursa_major": {
        "stars": {
            "Alkaid":   (0.78, 0.82, 0.6),
            "Mizar":    (0.67, 0.72, 0.55),
            "Alioth":   (0.55, 0.63, 0.65),
            "Megrez":   (0.47, 0.54, 0.45),
            "Phecda":   (0.51, 0.38, 0.55),
            "Merak":    (0.36, 0.36, 0.6),
            "Dubhe":    (0.32, 0.52, 0.7),
        },
        "lines": [
            ("Alkaid","Mizar"),("Mizar","Alioth"),("Alioth","Megrez"),
            ("Megrez","Phecda"),("Phecda","Merak"),("Merak","Dubhe"),("Dubhe","Megrez"),
        ],
    },
    "cassiopeia": {
        "stars": {
            "Segin":   (0.18, 0.55, 0.45),
            "Ruchbah": (0.32, 0.40, 0.5),
            "Gamma":   (0.50, 0.52, 0.65),
            "Schedar": (0.68, 0.40, 0.7),
            "Caph":    (0.82, 0.56, 0.6),
        },
        "lines": [("Segin","Ruchbah"),("Ruchbah","Gamma"),("Gamma","Schedar"),("Schedar","Caph")],
    },
    "scorpius": {
        "stars": {
            "Antares":  (0.38, 0.62, 0.95),
            "Graffias": (0.32, 0.72, 0.5),
            "Dschubba": (0.42, 0.75, 0.55),
            "Pi":       (0.24, 0.65, 0.45),
            "Sigma":    (0.44, 0.52, 0.5),
            "Tau":      (0.47, 0.44, 0.45),
            "Epsilon":  (0.50, 0.36, 0.5),
            "Mu":       (0.54, 0.28, 0.5),
            "Zeta":     (0.58, 0.22, 0.55),
            "Eta":      (0.62, 0.18, 0.45),
            "Theta":    (0.66, 0.22, 0.45),
            "Lambda":   (0.72, 0.28, 0.6),
            "Shaula":   (0.76, 0.24, 0.8),
            "Upsilon":  (0.78, 0.30, 0.45),
            "Kappa":    (0.80, 0.36, 0.5),
        },
        "lines": [
            ("Pi","Graffias"),("Graffias","Dschubba"),("Graffias","Antares"),
            ("Dschubba","Antares"),("Antares","Sigma"),("Sigma","Tau"),("Tau","Epsilon"),
            ("Epsilon","Mu"),("Mu","Zeta"),("Zeta","Eta"),("Eta","Theta"),
            ("Theta","Lambda"),("Lambda","Upsilon"),("Lambda","Shaula"),
            ("Upsilon","Kappa"),("Shaula","Kappa"),
        ],
    },
    "leo": {
        "stars": {
            "Regulus":  (0.25, 0.38, 0.9),
            "Eta":      (0.33, 0.52, 0.45),
            "Gamma":    (0.44, 0.64, 0.6),
            "Zeta":     (0.54, 0.66, 0.5),
            "Mu":       (0.62, 0.58, 0.45),
            "Epsilon":  (0.67, 0.44, 0.5),
            "Denebola": (0.80, 0.42, 0.75),
            "Delta":    (0.72, 0.56, 0.5),
            "Theta":    (0.35, 0.36, 0.45),
            "Eta2":     (0.30, 0.44, 0.4),
        },
        "lines": [
            ("Regulus","Theta"),("Theta","Eta2"),("Eta2","Eta"),("Eta","Gamma"),
            ("Gamma","Zeta"),("Zeta","Mu"),("Mu","Epsilon"),("Epsilon","Denebola"),
            ("Denebola","Delta"),("Delta","Epsilon"),("Delta","Zeta"),
            ("Regulus","Eta"),
        ],
    },
    "cygnus": {
        "stars": {
            "Deneb":   (0.50, 0.88, 0.9),
            "Sadr":    (0.50, 0.58, 0.65),
            "Gienah":  (0.28, 0.54, 0.5),
            "Delta":   (0.72, 0.54, 0.5),
            "Albireo": (0.50, 0.18, 0.6),
            "Zeta":    (0.38, 0.72, 0.4),
            "Epsilon": (0.62, 0.72, 0.4),
        },
        "lines": [
            ("Deneb","Sadr"),("Sadr","Albireo"),
            ("Gienah","Sadr"),("Sadr","Delta"),
            ("Deneb","Zeta"),("Deneb","Epsilon"),
        ],
    },
    "lyra": {
        "stars": {
            "Vega":    (0.50, 0.82, 0.95),
            "Sheliak": (0.38, 0.50, 0.55),
            "Sulafat": (0.62, 0.50, 0.55),
            "Delta1":  (0.38, 0.32, 0.4),
            "Delta2":  (0.44, 0.26, 0.4),
            "Zeta":    (0.56, 0.26, 0.4),
            "Epsilon": (0.62, 0.32, 0.4),
        },
        "lines": [
            ("Vega","Sheliak"),("Vega","Sulafat"),
            ("Sheliak","Delta1"),("Delta1","Delta2"),("Delta2","Zeta"),("Zeta","Epsilon"),
            ("Epsilon","Sulafat"),("Sheliak","Sulafat"),
        ],
    },
    "gemini": {
        "stars": {
            "Castor":   (0.62, 0.82, 0.75),
            "Pollux":   (0.70, 0.72, 0.85),
            "Alhena":   (0.68, 0.44, 0.55),
            "Wasat":    (0.54, 0.58, 0.45),
            "Mebsuda":  (0.44, 0.58, 0.5),
            "Mekbuda":  (0.40, 0.46, 0.4),
            "Mu":       (0.36, 0.62, 0.4),
            "Eta":      (0.32, 0.72, 0.5),
            "Tejat":    (0.28, 0.82, 0.55),
            "Propus":   (0.24, 0.74, 0.4),
        },
        "lines": [
            ("Castor","Mebsuda"),("Mebsuda","Mekbuda"),
            ("Pollux","Wasat"),("Wasat","Alhena"),
            ("Mebsuda","Mu"),("Mu","Eta"),("Eta","Tejat"),("Tejat","Propus"),
            ("Castor","Pollux"),
        ],
    },
    "aquila": {
        "stars": {
            "Altair":  (0.50, 0.55, 0.95),
            "Tarazed": (0.42, 0.65, 0.6),
            "Alshain": (0.58, 0.65, 0.5),
            "Delta":   (0.40, 0.44, 0.45),
            "Zeta":    (0.44, 0.34, 0.45),
            "Eta":     (0.54, 0.28, 0.5),
            "Theta":   (0.62, 0.36, 0.4),
            "Lambda":  (0.36, 0.56, 0.4),
        },
        "lines": [
            ("Tarazed","Altair"),("Altair","Alshain"),
            ("Lambda","Tarazed"),("Altair","Delta"),("Delta","Zeta"),("Zeta","Eta"),
            ("Eta","Theta"),("Theta","Alshain"),
        ],
    },
    "perseus": {
        "stars": {
            "Mirfak":  (0.50, 0.72, 0.85),
            "Algol":   (0.32, 0.54, 0.75),
            "Atik":    (0.44, 0.52, 0.45),
            "Delta":   (0.58, 0.58, 0.45),
            "Epsilon": (0.65, 0.68, 0.5),
            "Zeta":    (0.60, 0.80, 0.45),
            "Eta":     (0.42, 0.80, 0.45),
            "Gamma":   (0.38, 0.64, 0.5),
            "Theta":   (0.30, 0.44, 0.4),
            "Iota":    (0.40, 0.34, 0.4),
            "Kappa":   (0.50, 0.28, 0.45),
        },
        "lines": [
            ("Eta","Mirfak"),("Mirfak","Zeta"),("Mirfak","Delta"),("Mirfak","Epsilon"),
            ("Gamma","Algol"),("Algol","Atik"),("Atik","Delta"),
            ("Gamma","Mirfak"),("Algol","Theta"),("Theta","Iota"),("Iota","Kappa"),
        ],
    },
}

CONSTELLATION_ACCENT = "yellow"


def render_constellation(name: str, data: dict, W: int, H: int) -> Image.Image:
    accent_hex = CAT[CONSTELLATION_ACCENT]
    accent01 = hex_to_rgb01(accent_hex)
    bg01 = hex_to_rgb01(BG_HEX)

    dpi = 100
    fig, ax = plt.subplots(figsize=(W / dpi, H / dpi), dpi=dpi)
    fig.patch.set_facecolor(BG_HEX)
    ax.set_facecolor(BG_HEX)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)

    rng = random.Random(42)

    # Background star field — faint small dots
    n_bg_stars = 400
    for _ in range(n_bg_stars):
        sx = rng.random()
        sy = rng.random()
        # vary size and alpha slightly
        sz = rng.uniform(0.3, 2.0)
        alpha = rng.uniform(0.08, 0.25)
        ax.plot(sx, sy, "o", color=accent01, markersize=sz, alpha=alpha)

    stars = data["stars"]
    lines = data["lines"]

    # Constellation lines
    line_alpha = 0.65
    lw = max(0.8, W / 3840 * 1.2)
    for s1, s2 in lines:
        if s1 not in stars or s2 not in stars:
            continue
        x1, y1, _ = stars[s1]
        x2, y2, _ = stars[s2]
        ax.plot([x1, x2], [y1, y2], color=accent_hex, lw=lw, alpha=line_alpha, zorder=2)

    # Named stars
    max_marker = 10 * (W / 3840)
    for sname, (sx, sy, srel) in stars.items():
        ms = max_marker * (0.4 + 0.6 * srel)
        glow_dot(ax, sx, sy, ms, accent_hex, accent01, zorder=3)
        # Tiny label
        label_offset = 0.012
        ax.text(sx + label_offset, sy + label_offset, sname,
                color=accent_hex, fontsize=max(4, 6 * W / 3840),
                alpha=0.5, fontfamily="monospace", zorder=4,
                va="bottom", ha="left")

    # Constellation name label via PIL after rendering
    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches=None, pad_inches=0, dpi=dpi)
    plt.close(fig)
    buf.seek(0)
    canvas = Image.open(buf).convert("RGB")

    # Crop to canvas size in case matplotlib added any fringing
    canvas = canvas.resize((W, H), Image.LANCZOS)

    # Compute vertical center of constellation for label placement
    ys = [v[1] for v in stars.values()]
    min_y_norm = min(ys)
    # In image coords: y=0 at top, so constellation bottom = (1 - min_y_norm) * H
    label_top = int((1 - min_y_norm) * H) + int(H * 0.01)
    label_top = min(label_top, int(H * 0.93))

    display_name = name.replace("_", " ").title()
    add_label(canvas, display_name, accent_hex, W // 2, label_top)

    canvas = draw_center_haze(canvas, accent_hex, opacity=0.08, radius_frac=0.45)
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.22)

    return canvas


def generate_constellations(names: list, preview: bool):
    W, H = (PREVIEW_W, PREVIEW_H) if preview else (FULL_W, FULL_H)
    os.makedirs(OUT_DIR, exist_ok=True)
    suffix = "-preview" if preview else ""

    for name in names:
        if name not in CONSTELLATIONS:
            print(f"  Unknown constellation '{name}'. Available: {list(CONSTELLATIONS.keys())}")
            continue
        try:
            print(f"  Rendering constellation: {name}...", end=" ", flush=True)
            img = render_constellation(name, CONSTELLATIONS[name], W, H)
            safe = name.replace(" ", "-")
            out = os.path.join(OUT_DIR, f"constellation-{safe}-{CONSTELLATION_ACCENT}{suffix}.png")
            img.save(out)
            print(f"saved -> {os.path.basename(out)}")
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback; traceback.print_exc()


# ─────────────────────────────────────────────────────────────────────────────
# TYPE 2: Orbital diagrams
# ─────────────────────────────────────────────────────────────────────────────
ORBITAL_SYSTEMS = {
    # tuples: (display_name, semi_major_axis_au, eccentricity, radius_relative)
    # radius_relative: planet radius relative to Earth (1.0) — drives dot size
    "solar-system": {
        "star": "Sun", "star_r": 4.0,
        "planets": [
            ("Mercury", 0.387, 0.206, 0.38),
            ("Venus",   0.723, 0.007, 0.95),
            ("Earth",   1.000, 0.017, 1.00),
            ("Mars",    1.524, 0.093, 0.53),
            ("Jupiter", 5.203, 0.049, 4.50),
            ("Saturn",  9.537, 0.057, 3.80),
            ("Uranus",  19.19, 0.046, 1.65),
            ("Neptune", 30.07, 0.010, 1.60),
        ],
    },
    "trappist-1": {
        "star": "TRAPPIST-1", "star_r": 2.0,
        "label_prefix": "TRAPPIST-1 ",   # prepend to single-letter planet names
        "planets": [
            ("b", 0.01154, 0.006, 1.09),
            ("c", 0.01580, 0.007, 1.06),
            ("d", 0.02228, 0.000, 0.77),
            ("e", 0.02928, 0.005, 0.92),
            ("f", 0.03853, 0.010, 1.04),
            ("g", 0.04687, 0.002, 1.13),
            ("h", 0.06189, 0.006, 0.75),
        ],
    },
    "kepler-90": {
        "star": "Kepler-90", "star_r": 3.0,
        "label_prefix": "Kepler-90 ",
        "planets": [
            ("b", 0.074, 0.03, 1.31),
            ("c", 0.089, 0.01, 1.18),
            ("i", 0.100, 0.02, 1.32),
            ("d", 0.320, 0.02, 2.87),
            ("e", 0.420, 0.01, 2.67),
            ("f", 0.480, 0.02, 2.89),
            ("g", 0.710, 0.05, 8.13),
            ("h", 1.010, 0.03, 11.3),
        ],
    },
    "55-cancri": {
        "star": "55 Cnc", "star_r": 3.0,
        "label_prefix": "55 Cnc ",
        "planets": [
            ("e", 0.0154, 0.05, 1.88),
            ("b", 0.1134, 0.01, 9.0),
            ("c", 0.2373, 0.03, 6.3),
            ("f", 0.7708, 0.08, 7.0),
            ("d", 5.740,  0.02, 10.7),
        ],
    },
    "hr-8799": {
        "star": "HR 8799", "star_r": 3.5,
        "label_prefix": "HR 8799 ",
        "planets": [
            ("e", 14.5, 0.02, 9.0),
            ("d", 24.0, 0.04, 9.5),
            ("c", 38.0, 0.06, 9.5),
            ("b", 68.0, 0.02, 8.0),
        ],
    },
}

ORBITAL_ACCENT = "mauve"


def render_orbital(sys_name: str, data: dict, W: int, H: int) -> Image.Image:
    accent_hex = CAT[ORBITAL_ACCENT]
    accent01   = hex_to_rgb01(accent_hex)
    prefix     = data.get("label_prefix", "")

    dpi = 100
    fig, ax = plt.subplots(figsize=(W / dpi, H / dpi), dpi=dpi)
    fig.patch.set_facecolor(BG_HEX)
    ax.set_facecolor(BG_HEX)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)

    planets   = data["planets"]
    star_name = data["star"]
    star_r    = data.get("star_r", 3.0)

    max_sma = max(p[1] for p in planets)

    def scale_r(sma):
        # sqrt scale keeps inner planets legible
        return math.sqrt(sma / max_sma) * 0.40

    # Sizes in data-space markersize units (at 3840px dpi=100 → 1 data unit = 100px)
    # We work in normalized [0,1] coords, so markersize is in display points.
    scale = W / 3840
    base_planet_ms = 7.0 * scale     # Earth-sized planet at 4K
    max_planet_ms  = 22.0 * scale    # cap for giants
    label_fs       = 8.5 * scale
    orbit_lw       = 1.0 * scale

    cx, cy = 0.5, 0.5

    # Evenly space planets around their orbits (seed-stable but spread out)
    rng = random.Random(42)
    angles = [rng.uniform(0, 2 * math.pi) for _ in planets]

    for i, (pname, sma, ecc, prad) in enumerate(planets):
        a = scale_r(sma)
        b = a * math.sqrt(1 - ecc ** 2)
        c_focus = a * ecc
        ex = cx - c_focus

        # Orbit ellipse
        theta = np.linspace(0, 2 * math.pi, 400)
        px = ex + a * np.cos(theta)
        py = cy + b * np.sin(theta)
        ax.plot(px, py, color=accent_hex, lw=orbit_lw, alpha=0.55, zorder=2)

        # Planet position
        ang     = angles[i]
        planet_x = ex + a * math.cos(ang)
        planet_y = cy + b * math.sin(ang)

        # Dot size: scale by planet radius (clamped)
        dot_ms = min(max_planet_ms, base_planet_ms * max(0.5, math.sqrt(prad)))
        glow_dot(ax, planet_x, planet_y, dot_ms, accent_hex, accent01, zorder=4)

        # Label: use prefix for single-letter names
        display_label = (prefix + pname) if (len(pname) <= 2 and prefix) else pname
        # Offset label away from center
        dx = planet_x - cx
        dy = planet_y - cy
        norm = math.sqrt(dx**2 + dy**2) or 1
        lx = planet_x + (dx / norm) * 0.022
        ly = planet_y + (dy / norm) * 0.022
        ax.text(lx, ly, display_label, color=accent_hex, fontsize=label_fs,
                alpha=0.80, fontfamily="monospace", zorder=5,
                ha="center", va="center")

    # Central star — glow dot, larger
    star_ms = star_r * scale * 3.5
    glow_dot(ax, cx, cy, star_ms, accent_hex, accent01, zorder=6)
    ax.text(cx, cy - 0.055, star_name, color=accent_hex,
            fontsize=label_fs * 1.1, alpha=0.85, fontfamily="monospace",
            zorder=7, ha="center", va="top")

    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches=None, pad_inches=0, dpi=dpi)
    plt.close(fig)
    buf.seek(0)
    canvas = Image.open(buf).convert("RGB")
    canvas = canvas.resize((W, H), Image.LANCZOS)

    display_name = sys_name.replace("-", " ").title()
    add_label(canvas, display_name, accent_hex, W // 2, int(H * 0.91))
    return canvas


def generate_orbitals(names: list, preview: bool):
    W, H = (PREVIEW_W, PREVIEW_H) if preview else (FULL_W, FULL_H)
    os.makedirs(OUT_DIR, exist_ok=True)
    suffix = "-preview" if preview else ""

    for name in names:
        if name not in ORBITAL_SYSTEMS:
            print(f"  Unknown orbital system '{name}'. Available: {list(ORBITAL_SYSTEMS.keys())}")
            continue
        try:
            print(f"  Rendering orbital: {name}...", end=" ", flush=True)
            img = render_orbital(name, ORBITAL_SYSTEMS[name], W, H)
            safe = name.replace(" ", "-")
            out = os.path.join(OUT_DIR, f"orbital-{safe}-{ORBITAL_ACCENT}{suffix}.png")
            img.save(out)
            print(f"saved -> {os.path.basename(out)}")
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback; traceback.print_exc()


# ─────────────────────────────────────────────────────────────────────────────
# TYPE 3: Amino acids (RDKit + PubChemPy — same pipeline as molecule generator)
# ─────────────────────────────────────────────────────────────────────────────
AMINO_ACIDS = {
    # Aromatic
    "tryptophan":    "mauve",
    "phenylalanine": "lavender",
    "tyrosine":      "pink",
    # Charged
    "aspartate":     "red",
    "glutamate":     "maroon",
    "lysine":        "blue",
    "arginine":      "sapphire",
    "histidine":     "sky",
    # Polar uncharged
    "serine":        "teal",
    "threonine":     "green",
    "cysteine":      "yellow",
    "asparagine":    "flamingo",
    "glutamine":     "peach",
    # Nonpolar
    "glycine":       "subtext1",
    "alanine":       "text",
    "valine":        "rosewater",
    "leucine":       "flamingo",
    "isoleucine":    "peach",
    "methionine":    "yellow",
    "proline":       "green",
}

# SMILES overrides for speed / reliability
AMINO_SMILES_OVERRIDE = {
    "tryptophan":    "C1=CC2=C(NC=C2CC(N)C(=O)O)C=C1",
    "phenylalanine": "N[C@@H](Cc1ccccc1)C(=O)O",
    "tyrosine":      "N[C@@H](Cc1ccc(O)cc1)C(=O)O",
    "aspartate":     "N[C@@H](CC(=O)O)C(=O)O",
    "glutamate":     "N[C@@H](CCC(=O)O)C(=O)O",
    "lysine":        "N[C@@H](CCCCN)C(=O)O",
    "arginine":      "N[C@@H](CCCNC(=N)N)C(=O)O",
    "histidine":     "N[C@@H](Cc1cnc[nH]1)C(=O)O",
    "serine":        "N[C@@H](CO)C(=O)O",
    "threonine":     "N[C@@H]([C@@H](O)C)C(=O)O",
    "cysteine":      "N[C@@H](CS)C(=O)O",
    "asparagine":    "N[C@@H](CC(=O)N)C(=O)O",
    "glutamine":     "N[C@@H](CCC(=O)N)C(=O)O",
    "glycine":       "NCC(=O)O",
    "alanine":       "N[C@@H](C)C(=O)O",
    "valine":        "N[C@@H](C(C)C)C(=O)O",
    "leucine":       "N[C@@H](CC(C)C)C(=O)O",
    "isoleucine":    "N[C@@H]([C@@H](C)CC)C(=O)O",
    "methionine":    "N[C@@H](CCSC)C(=O)O",
    "proline":       "N1[C@@H](CCC1)C(=O)O",
}

MOL_DRAW_W, MOL_DRAW_H = 1400, 1050
BOND_WIDTH = 3.5
PADDING = 0.12


def render_amino_mol(smiles: str, accent_hex: str) -> Image.Image:
    """Render amino acid structure via RDKit, return cropped PIL image."""
    try:
        from rdkit import Chem
        from rdkit.Chem import AllChem
        from rdkit.Chem.Draw import rdMolDraw2D
    except ImportError:
        raise ImportError("RDKit not available — cannot render amino acid structures.")

    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise ValueError(f"RDKit could not parse SMILES: {smiles}")
    AllChem.Compute2DCoords(mol)

    accent01 = hex_to_rgb01(accent_hex)
    bg01 = hex_to_rgb01(BG_HEX)

    drawer = rdMolDraw2D.MolDraw2DCairo(MOL_DRAW_W, MOL_DRAW_H)
    opts = drawer.drawOptions()
    opts.setAtomPalette({i: accent01 for i in range(1, 120)})
    opts.backgroundColour = bg01
    opts.bondLineWidth = BOND_WIDTH
    opts.padding = PADDING
    opts.multipleBondOffset = 0.18

    drawer.DrawMolecule(mol)
    drawer.FinishDrawing()

    img = Image.open(io.BytesIO(drawer.GetDrawingText())).convert("RGBA")

    # Crop to content
    bg_rgb = hex_to_rgb(BG_HEX)
    arr = np.array(img)
    bg = np.array(bg_rgb, dtype=np.uint8)
    diff = np.abs(arr[:, :, :3].astype(int) - bg.astype(int)).sum(axis=2)
    rows = np.any(diff > 8, axis=1)
    cols = np.any(diff > 8, axis=0)
    if not rows.any():
        return img
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    pad = 20
    rmin = max(0, rmin - pad)
    rmax = min(img.height - 1, rmax + pad)
    cmin = max(0, cmin - pad)
    cmax = min(img.width - 1, cmax + pad)
    return img.crop((cmin, rmin, cmax + 1, rmax + 1))


def smiles_for_amino(name: str) -> str:
    if name in AMINO_SMILES_OVERRIDE:
        return AMINO_SMILES_OVERRIDE[name]
    try:
        import pubchempy as pcp
        results = pcp.get_compounds(name, "name")
        if not results:
            raise ValueError(f"PubChem: no results for '{name}'")
        return results[0].smiles
    except ImportError:
        raise ImportError("pubchempy not available and no SMILES override for this compound.")


def make_aminoacid_wallpaper(name: str, accent_name: str, W: int, H: int) -> Image.Image:
    accent_hex = CAT[accent_name]

    smiles = smiles_for_amino(name)
    mol_img = render_amino_mol(smiles, accent_hex)

    canvas = Image.new("RGB", (W, H), hex_to_rgb(BG_HEX))

    # Scale molecule to ~22% of canvas width
    target_w = int(W * 0.22)
    mw, mh = mol_img.size
    scale = target_w / mw
    new_w = int(mw * scale)
    new_h = int(mh * scale)
    mol_scaled = mol_img.resize((new_w, new_h), Image.LANCZOS)

    label_h = int(H * 0.025)
    label_gap = int(H * 0.018)
    mol_x = (W - new_w) // 2
    mol_y = (H - new_h - label_h - label_gap) // 2

    canvas.paste(mol_scaled, (mol_x, mol_y), mol_scaled)

    label = name.replace("-", " ").title()
    label_top = mol_y + new_h + label_gap
    add_label(canvas, label, accent_hex, W // 2, label_top)

    return canvas


def generate_aminoacids(names: list, preview: bool):
    W, H = (PREVIEW_W, PREVIEW_H) if preview else (FULL_W, FULL_H)
    os.makedirs(OUT_DIR, exist_ok=True)
    suffix = "-preview" if preview else ""

    for name in names:
        if name not in AMINO_ACIDS:
            print(f"  Unknown amino acid '{name}'. Available: {list(AMINO_ACIDS.keys())}")
            continue
        accent = AMINO_ACIDS[name]
        try:
            print(f"  Rendering amino acid: {name} ({accent})...", end=" ", flush=True)
            img = make_aminoacid_wallpaper(name, accent, W, H)
            safe = name.replace(" ", "-")
            out = os.path.join(OUT_DIR, f"aminoacid-{safe}-{accent}{suffix}.png")
            img.save(out)
            print(f"saved -> {os.path.basename(out)}")
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback; traceback.print_exc()


# ─────────────────────────────────────────────────────────────────────────────
# TYPE 4: Feynman diagrams
# ─────────────────────────────────────────────────────────────────────────────
FEYNMAN_ACCENT = "peach"

# --- drawing helpers ---------------------------------------------------------

def arrow_line(ax, x1, y1, x2, y2, color, lw=1.5, dashed=False):
    """Draw a straight fermion line with an arrow at the midpoint."""
    ls = '--' if dashed else '-'
    # Draw the line
    ax.plot([x1, x2], [y1, y2], color=color, lw=lw, linestyle=ls, zorder=3)
    # Arrow at midpoint
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    dx, dy = x2 - x1, y2 - y1
    ax.annotate('', xy=(mx + dx * 0.001, my + dy * 0.001),
                xytext=(mx - dx * 0.001, my - dy * 0.001),
                arrowprops=dict(arrowstyle='->', color=color, lw=lw),
                zorder=4)


def wiggly(ax, x1, y1, x2, y2, color, n=12, amp=0.03, lw=1.5):
    """Draw a wiggly photon/boson line."""
    t = np.linspace(0, 1, 300)
    dx, dy = x2 - x1, y2 - y1
    length = np.sqrt(dx ** 2 + dy ** 2)
    if length < 1e-9:
        return
    nx, ny = -dy / length, dx / length
    wave = amp * np.sin(n * np.pi * t)
    ax.plot(x1 + t * dx + wave * nx, y1 + t * dy + wave * ny,
            color=color, lw=lw, zorder=3)


def particle_label(ax, x, y, text, color, fs=10, ha='center', va='center', offset=(0, 0)):
    ax.text(x + offset[0], y + offset[1], text, color=color,
            fontsize=fs, ha=ha, va=va, fontfamily='monospace', zorder=5)


def setup_feynman_ax(fig, ax, accent_hex):
    fig.patch.set_facecolor(BG_HEX)
    ax.set_facecolor(BG_HEX)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)


# --- individual diagrams -----------------------------------------------------

def draw_electron_positron(ax, accent_hex, lw, fs, amp):
    """e+e- → γ → μ+μ- (X shape with wiggly center)"""
    cx, cy = 0.5, 0.5
    # Incoming: e- (bottom-left → vertex left), e+ (bottom-right → vertex right)
    # Outgoing: μ- (vertex left → top-right), μ+ (vertex right → top-left)
    # Two vertices
    vl = (0.38, 0.50)
    vr = (0.62, 0.50)

    # e- incoming bottom-left to vl
    arrow_line(ax, 0.18, 0.22, vl[0], vl[1], accent_hex, lw=lw)
    particle_label(ax, 0.18, 0.22, 'e⁻', accent_hex, fs=fs, ha='right', va='top')

    # e+ incoming bottom-right to vr (dashed for antiparticle)
    arrow_line(ax, 0.82, 0.22, vr[0], vr[1], accent_hex, lw=lw, dashed=True)
    particle_label(ax, 0.82, 0.22, 'e⁺', accent_hex, fs=fs, ha='left', va='top')

    # Virtual photon between vertices (wiggly)
    wiggly(ax, vl[0], vl[1], vr[0], vr[1], accent_hex, n=8, amp=amp * 0.7, lw=lw)
    particle_label(ax, 0.50, 0.54, 'γ', accent_hex, fs=fs * 1.1)

    # μ- outgoing vl → top-left
    arrow_line(ax, vl[0], vl[1], 0.18, 0.78, accent_hex, lw=lw)
    particle_label(ax, 0.18, 0.78, 'μ⁻', accent_hex, fs=fs, ha='right', va='bottom')

    # μ+ outgoing vr → top-right (dashed)
    arrow_line(ax, vr[0], vr[1], 0.82, 0.78, accent_hex, lw=lw, dashed=True)
    particle_label(ax, 0.82, 0.78, 'μ⁺', accent_hex, fs=fs, ha='left', va='bottom')

    # Vertex dots
    for vx, vy in [vl, vr]:
        ax.plot(vx, vy, 'o', color=accent_hex, markersize=5 * lw, zorder=6)


def draw_compton_scattering(ax, accent_hex, lw, fs, amp):
    """Compton: e- enters bottom-left, photon enters top-left; scatter at vertex."""
    v = (0.50, 0.50)

    # Incoming e- bottom-left → vertex
    arrow_line(ax, 0.15, 0.20, v[0], v[1], accent_hex, lw=lw)
    particle_label(ax, 0.15, 0.20, 'e⁻', accent_hex, fs=fs, ha='right', va='top')

    # Incoming γ top-left → vertex (wiggly)
    wiggly(ax, 0.15, 0.80, v[0], v[1], accent_hex, n=10, amp=amp, lw=lw)
    particle_label(ax, 0.15, 0.80, 'γ', accent_hex, fs=fs, ha='right', va='bottom')

    # Outgoing e- vertex → top-right
    arrow_line(ax, v[0], v[1], 0.85, 0.80, accent_hex, lw=lw)
    particle_label(ax, 0.85, 0.80, 'e⁻', accent_hex, fs=fs, ha='left', va='bottom')

    # Outgoing γ vertex → bottom-right (wiggly)
    wiggly(ax, v[0], v[1], 0.85, 0.20, accent_hex, n=10, amp=amp, lw=lw)
    particle_label(ax, 0.85, 0.20, 'γ', accent_hex, fs=fs, ha='left', va='top')

    ax.plot(v[0], v[1], 'o', color=accent_hex, markersize=6 * lw, zorder=6)


def draw_pair_production(ax, accent_hex, lw, fs, amp):
    """Pair production: γ → e+e-"""
    v = (0.45, 0.50)

    # Incoming photon from left (wiggly)
    wiggly(ax, 0.10, 0.50, v[0], v[1], accent_hex, n=10, amp=amp, lw=lw)
    particle_label(ax, 0.10, 0.50, 'γ', accent_hex, fs=fs, ha='right')

    # e- outgoing → top-right
    arrow_line(ax, v[0], v[1], 0.85, 0.78, accent_hex, lw=lw)
    particle_label(ax, 0.85, 0.78, 'e⁻', accent_hex, fs=fs, ha='left', va='bottom')

    # e+ outgoing → bottom-right (dashed)
    arrow_line(ax, v[0], v[1], 0.85, 0.22, accent_hex, lw=lw, dashed=True)
    particle_label(ax, 0.85, 0.22, 'e⁺', accent_hex, fs=fs, ha='left', va='top')

    ax.plot(v[0], v[1], 'o', color=accent_hex, markersize=6 * lw, zorder=6)


def draw_beta_decay(ax, accent_hex, lw, fs, amp):
    """Beta decay: n → p + W- → p + e- + ν̄_e"""
    vw = (0.50, 0.50)   # W- emission vertex

    # Neutron → proton (horizontal line through vertex)
    arrow_line(ax, 0.12, 0.50, vw[0], vw[1], accent_hex, lw=lw)
    arrow_line(ax, vw[0], vw[1], 0.88, 0.50, accent_hex, lw=lw)
    particle_label(ax, 0.12, 0.50, 'n', accent_hex, fs=fs, ha='right')
    particle_label(ax, 0.88, 0.50, 'p', accent_hex, fs=fs, ha='left')

    # W- boson wiggly downward
    vw2 = (0.50, 0.24)
    wiggly(ax, vw[0], vw[1], vw2[0], vw2[1], accent_hex, n=7, amp=amp * 0.8, lw=lw)
    particle_label(ax, 0.53, 0.37, 'W⁻', accent_hex, fs=fs, ha='left')

    # e- from W- vertex → bottom-left
    arrow_line(ax, vw2[0], vw2[1], 0.22, 0.08, accent_hex, lw=lw)
    particle_label(ax, 0.22, 0.08, 'e⁻', accent_hex, fs=fs, ha='right', va='top')

    # ν̄_e from W- vertex → bottom-right (dashed)
    arrow_line(ax, vw2[0], vw2[1], 0.78, 0.08, accent_hex, lw=lw, dashed=True)
    particle_label(ax, 0.78, 0.08, 'ν̄ₑ', accent_hex, fs=fs, ha='left', va='top')

    for vx, vy in [vw, vw2]:
        ax.plot(vx, vy, 'o', color=accent_hex, markersize=5 * lw, zorder=6)


def draw_electron_scattering(ax, accent_hex, lw, fs, amp):
    """Møller scattering: e-e- exchange virtual photon."""
    # Two electrons approach from left, leave to right; virtual photon vertical between them
    vt = (0.44, 0.70)   # top vertex
    vb = (0.44, 0.30)   # bottom vertex

    # Top e- incoming bottom-left → vt
    arrow_line(ax, 0.12, 0.82, vt[0], vt[1], accent_hex, lw=lw)
    particle_label(ax, 0.12, 0.82, 'e⁻', accent_hex, fs=fs, ha='right', va='bottom')

    # Bottom e- incoming top-left → vb
    arrow_line(ax, 0.12, 0.18, vb[0], vb[1], accent_hex, lw=lw)
    particle_label(ax, 0.12, 0.18, 'e⁻', accent_hex, fs=fs, ha='right', va='top')

    # Virtual photon between vertices
    wiggly(ax, vt[0], vt[1], vb[0], vb[1], accent_hex, n=8, amp=amp * 0.6, lw=lw)
    particle_label(ax, 0.38, 0.50, 'γ*', accent_hex, fs=fs, ha='right')

    # Top e- outgoing vt → top-right
    arrow_line(ax, vt[0], vt[1], 0.88, 0.82, accent_hex, lw=lw)
    particle_label(ax, 0.88, 0.82, 'e⁻', accent_hex, fs=fs, ha='left', va='bottom')

    # Bottom e- outgoing vb → bottom-right
    arrow_line(ax, vb[0], vb[1], 0.88, 0.18, accent_hex, lw=lw)
    particle_label(ax, 0.88, 0.18, 'e⁻', accent_hex, fs=fs, ha='left', va='top')

    for vx, vy in [vt, vb]:
        ax.plot(vx, vy, 'o', color=accent_hex, markersize=5 * lw, zorder=6)


FEYNMAN_DIAGRAMS = {
    "electron-positron": draw_electron_positron,
    "compton-scattering": draw_compton_scattering,
    "pair-production": draw_pair_production,
    "beta-decay": draw_beta_decay,
    "electron-scattering": draw_electron_scattering,
}


def render_feynman(diag_name: str, draw_fn, W: int, H: int) -> Image.Image:
    accent_hex = CAT[FEYNMAN_ACCENT]

    dpi = 100
    fig, ax = plt.subplots(figsize=(W / dpi, H / dpi), dpi=dpi)
    setup_feynman_ax(fig, ax, accent_hex)

    lw = max(1.0, 2.0 * W / 3840)
    fs = max(7, 12 * W / 3840)
    amp = max(0.015, 0.030 * W / 3840)

    draw_fn(ax, accent_hex, lw=lw, fs=fs, amp=amp)

    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches=None, pad_inches=0, dpi=dpi)
    plt.close(fig)
    buf.seek(0)
    canvas = Image.open(buf).convert("RGB")
    canvas = canvas.resize((W, H), Image.LANCZOS)

    label = diag_name.replace("-", " ").title()
    label_top = int(H * 0.90)
    add_label(canvas, label, accent_hex, W // 2, label_top)

    return canvas


def generate_feynman(names: list, preview: bool):
    W, H = (PREVIEW_W, PREVIEW_H) if preview else (FULL_W, FULL_H)
    os.makedirs(OUT_DIR, exist_ok=True)
    suffix = "-preview" if preview else ""

    for name in names:
        if name not in FEYNMAN_DIAGRAMS:
            print(f"  Unknown Feynman diagram '{name}'. Available: {list(FEYNMAN_DIAGRAMS.keys())}")
            continue
        try:
            print(f"  Rendering Feynman: {name}...", end=" ", flush=True)
            img = render_feynman(name, FEYNMAN_DIAGRAMS[name], W, H)
            safe = name.replace(" ", "-")
            out = os.path.join(OUT_DIR, f"feynman-{safe}-{FEYNMAN_ACCENT}{suffix}.png")
            img.save(out)
            print(f"saved -> {os.path.basename(out)}")
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback; traceback.print_exc()


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Catppuccin science wallpaper generator")
    parser.add_argument(
        "--type",
        choices=["constellation", "orbital", "aminoacid", "feynman", "all"],
        default="all",
        help="Type of wallpaper to generate",
    )
    parser.add_argument("--name", help="Specific item name within a type")
    parser.add_argument("--preview", action="store_true", help="Generate 1920x1080 preview")
    args = parser.parse_args()

    preview = args.preview
    mode = "PREVIEW 1920x1080" if preview else "FULL 3840x2160"
    print(f"[generate-science-wallpapers] mode={mode}")

    types_to_run = (
        ["constellation", "orbital", "aminoacid", "feynman"]
        if args.type == "all"
        else [args.type]
    )

    for t in types_to_run:
        if t == "constellation":
            names = [args.name] if args.name else list(CONSTELLATIONS.keys())
            print(f"\n=== Constellations ({len(names)}) ===")
            generate_constellations(names, preview)

        elif t == "orbital":
            names = [args.name] if args.name else list(ORBITAL_SYSTEMS.keys())
            print(f"\n=== Orbital systems ({len(names)}) ===")
            generate_orbitals(names, preview)

        elif t == "aminoacid":
            names = [args.name] if args.name else list(AMINO_ACIDS.keys())
            print(f"\n=== Amino acids ({len(names)}) ===")
            generate_aminoacids(names, preview)

        elif t == "feynman":
            names = [args.name] if args.name else list(FEYNMAN_DIAGRAMS.keys())
            print(f"\n=== Feynman diagrams ({len(names)}) ===")
            generate_feynman(names, preview)

    print("\nDone.")


if __name__ == "__main__":
    main()
