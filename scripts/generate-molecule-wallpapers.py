#!/usr/bin/env python3
"""
Native Catppuccin molecule wallpaper generator.
Generates 3840x2160 wallpapers using RDKit + PubChemPy.

Usage:
  python3 generate-molecule-wallpapers.py             # generate all defined molecules
  python3 generate-molecule-wallpapers.py serotonin   # generate one by name
  python3 generate-molecule-wallpapers.py --preview   # 1920x1080 output
"""

import sys, os, math, random, hashlib
import pubchempy as pcp
from rdkit import Chem
from rdkit.Chem import AllChem
from rdkit.Chem.Draw import rdMolDraw2D
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import io
import numpy as np

# --------------------------------------------------------------------------- #
# Catppuccin Mocha palette
# --------------------------------------------------------------------------- #
CAT = {
    "base":     "#1e1e2e",
    "mantle":   "#181825",
    "crust":    "#11111b",
    "text":     "#cdd6f4",
    "subtext1": "#bac2de",
    "subtext0": "#a6adc8",
    "rosewater":"#f5e0dc",
    "flamingo": "#f2cdcd",
    "pink":     "#f5c2e7",
    "mauve":    "#cba6f7",
    "red":      "#f38ba8",
    "maroon":   "#eba0ac",
    "peach":    "#fab387",
    "yellow":   "#f9e2af",
    "green":    "#a6e3a1",
    "teal":     "#94e2d5",
    "sky":      "#89dceb",
    "sapphire": "#74c7ec",
    "blue":     "#89b4fa",
    "lavender": "#b4befe",
}

def hex_to_rgb01(h):
    h = h.lstrip("#")
    return (int(h[0:2],16)/255, int(h[2:4],16)/255, int(h[4:6],16)/255)

def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

# --------------------------------------------------------------------------- #
# Visual effects helpers
# --------------------------------------------------------------------------- #

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
    overlay[:, :, 0] = cr
    overlay[:, :, 1] = cg
    overlay[:, :, 2] = cb
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
    overlay[:, :, 0] = ar
    overlay[:, :, 1] = ag
    overlay[:, :, 2] = ab
    overlay[:, :, 3] = alpha
    result = Image.alpha_composite(canvas.convert("RGBA"),
                                   Image.fromarray(overlay, "RGBA"))
    return result.convert("RGB")


# --------------------------------------------------------------------------- #
# Molecule definitions: name -> accent color
# --------------------------------------------------------------------------- #
MOLECULES = {
    # Neurotransmitters / hormones
    "serotonin":     "teal",
    "dopamine":      "blue",
    "melatonin":     "mauve",
    "atp":           "blue",
    "caffeine":      "blue",
    "adrenaline":    "red",
    "noradrenaline": "peach",
    "oxytocin":      "pink",
    "cortisol":      "yellow",
    "histamine":     "green",
    # Everyday / nature
    "aspirin":       "sapphire",
    "ibuprofen":     "sky",
    "paracetamol":   "teal",
    "ethanol":       "lavender",
    "capsaicin":     "red",
    "luciferin":     "yellow",
    "chlorophyll":   "green",
    "glucose":       "peach",
    "vitamin c":     "flamingo",
}

# SMILES overrides for names PubChem may misread or for speed
SMILES_OVERRIDE = {
    "atp": "c1nc(c2c(n1)n(cn2)[C@@H]3[C@@H]([C@@H]([C@H](O3)COP(=O)(O)OP(=O)(O)OP(=O)(O)O)O)O)N",
    "vitamin c": "C([C@@H]([C@@H]1C(=C(C(=O)O1)O)O)O)O",
}

# Canvas & drawing constants
CANVAS_W, CANVAS_H = 3840, 2160
MOL_DRAW_W, MOL_DRAW_H = 1400, 1050   # RDKit render size (cropped to molecule)
BOND_WIDTH = 3.5
PADDING = 0.12


# --------------------------------------------------------------------------- #
# Core render function
# --------------------------------------------------------------------------- #

def smiles_for(name: str) -> str:
    if name in SMILES_OVERRIDE:
        return SMILES_OVERRIDE[name]
    results = pcp.get_compounds(name, "name")
    if not results:
        raise ValueError(f"PubChem: no results for '{name}'")
    return results[0].smiles


def render_molecule(smiles: str, accent_hex: str, bg_hex: str) -> Image.Image:
    """Returns a PIL Image of the molecule on transparent background (actual bounds)."""
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise ValueError(f"RDKit could not parse SMILES: {smiles}")
    AllChem.Compute2DCoords(mol)

    accent01 = hex_to_rgb01(accent_hex)
    bg01     = hex_to_rgb01(bg_hex)

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

    # Crop to content: find bounding box of non-background pixels
    bg_rgb = hex_to_rgb(bg_hex)
    r, g, b, _ = img.split()
    # Mask: pixels that differ from bg
    arr = np.array(img)
    bg = np.array(bg_rgb, dtype=np.uint8)
    diff = np.abs(arr[:,:,:3].astype(int) - bg.astype(int)).sum(axis=2)
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
    cropped = img.crop((cmin, rmin, cmax+1, rmax+1))
    # Make background pixels fully transparent so the canvas haze shows through
    c_arr = np.array(cropped)
    c_diff = np.abs(c_arr[:, :, :3].astype(int) - bg.astype(int)).sum(axis=2)
    c_arr[:, :, 3] = np.where(c_diff > 8, 255, 0)
    return Image.fromarray(c_arr, "RGBA")


def make_wallpaper(name: str, accent_name: str, preview: bool = False) -> Image.Image:
    accent_hex = CAT[accent_name]
    bg_hex     = CAT["base"]

    print(f"  Fetching SMILES for '{name}'...", end=" ", flush=True)
    smiles = smiles_for(name)
    print(f"rendering ({accent_name})...", end=" ", flush=True)

    mol_img = render_molecule(smiles, accent_hex, bg_hex)

    # Canvas
    W, H = (1920, 1080) if preview else (CANVAS_W, CANVAS_H)
    canvas = Image.new("RGB", (W, H), hex_to_rgb(bg_hex))

    # Scale molecule to fit ~28% of canvas width, maintain aspect
    target_w = int(W * 0.28)
    mw, mh = mol_img.size
    scale = target_w / mw
    new_w = int(mw * scale)
    new_h = int(mh * scale)

    mol_scaled = mol_img.resize((new_w, new_h), Image.LANCZOS)

    # Center molecule slightly above vertical center (leave room for label)
    label_h = int(H * 0.025)
    label_gap = int(H * 0.018)
    mol_x = (W - new_w) // 2
    mol_y = (H - new_h - label_h - label_gap) // 2

    # Background star field (seeded per molecule name for stability)
    seed = int(hashlib.md5(name.encode()).hexdigest(), 16) % (2 ** 31)
    canvas = draw_star_field(canvas, accent_hex, seed=seed, n_stars=300)

    # Soft accent haze at center
    canvas = draw_center_haze(canvas, accent_hex, opacity=0.10, radius_frac=0.30)

    canvas.paste(mol_scaled, (mol_x, mol_y), mol_scaled)

    # Label
    draw = ImageDraw.Draw(canvas)
    label = name.replace("-", " ").title()
    label_color = hex_to_rgb(accent_hex)

    font_size = label_h
    font = None
    font_candidates = [
        r"C:\Windows\Fonts\segoeuil.ttf",   # Segoe UI Light  (best match)
        r"C:\Windows\Fonts\segoeuisl.ttf",  # Segoe UI Semilight
        r"C:\Windows\Fonts\segoeui.ttf",    # Segoe UI Regular
        r"C:\Windows\Fonts\arial.ttf",
        r"C:\Windows\Fonts\calibri.ttf",
    ]
    for fc in font_candidates:
        if os.path.exists(fc):
            try:
                font = ImageFont.truetype(fc, font_size)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    label_x = (W - tw) // 2
    label_y = mol_y + new_h + label_gap

    draw.text((label_x, label_y), label, fill=label_color, font=font)

    # Post-processing: vignette + glow bloom
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.28)

    return canvas


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

OUT_DIR  = r"C:\Users\Mathias\Documents\Linux-Setup\images\wallpaper-rotation\catppuccin"
PREVIEW  = "--preview" in sys.argv
TARGET   = [a for a in sys.argv[1:] if not a.startswith("--")]

os.makedirs(OUT_DIR, exist_ok=True)

molecules_to_run = {}
if TARGET:
    for t in TARGET:
        t = t.lower()
        if t in MOLECULES:
            molecules_to_run[t] = MOLECULES[t]
        else:
            print(f"Unknown molecule '{t}'. Available: {list(MOLECULES.keys())}")
            sys.exit(1)
else:
    molecules_to_run = MOLECULES

suffix = "-preview" if PREVIEW else ""
mode   = "PREVIEW 1920x1080" if PREVIEW else "FULL 3840x2160"
print(f"Generating {len(molecules_to_run)} molecule wallpapers [{mode}]")

for name, accent in molecules_to_run.items():
    try:
        img = make_wallpaper(name, accent, preview=PREVIEW)
        safe_name = name.replace(" ", "-")
        out_path = os.path.join(OUT_DIR, f"molecule-{safe_name}-{accent}{suffix}.png")
        img.save(out_path)
        print(f"saved -> {os.path.basename(out_path)}")
    except Exception as e:
        print(f"ERROR: {e}")

# Clean up test file if present
test = r"C:\Users\Mathias\Documents\Linux-Setup\test_mol.png"
if os.path.exists(test):
    os.remove(test)

print("Done.")
