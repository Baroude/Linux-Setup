# Wallpaper Visual Improvements — Cosmic Ethereal

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add soft glow bloom, background star fields, center accent haze, and vignette to all generated wallpapers for a cosmic/ethereal aesthetic.

**Architecture:** Four reusable PIL utility functions (`apply_vignette`, `apply_glow_bloom`, `draw_star_field`, `draw_center_haze`) are added to both scripts. Each wallpaper type's render function calls them as a post-processing final step. No new dependencies — PIL, numpy, random already imported.

**Tech Stack:** Python, PIL/Pillow, numpy, matplotlib (already in use)

---

## Reference: Current outputs to understand baseline

Before touching anything, view a few existing previews to calibrate:
```bash
python scripts/generate-molecule-wallpapers.py serotonin --preview
# output: images/wallpaper-rotation/catppuccin/molecule-serotonin-teal-preview.png
python scripts/generate-science-wallpapers.py --type constellation --name orion --preview
python scripts/generate-science-wallpapers.py --type orbital --name solar-system --preview
```

---

## Task 1: Add utility helpers + improve molecule wallpapers

**Files:**
- Modify: `scripts/generate-molecule-wallpapers.py`

### Step 1: Add missing imports at the top

In `generate-molecule-wallpapers.py`, add `import math` and `import random` to the existing import block (PIL and numpy already imported).

```python
import sys, os, textwrap, math, random
```

### Step 2: Add four utility functions after `hex_to_rgb`

Insert these after the `hex_to_rgb` function (around line 52):

```python
# --------------------------------------------------------------------------- #
# Visual effects helpers
# --------------------------------------------------------------------------- #

def apply_vignette(canvas: Image.Image, strength: float = 0.25) -> Image.Image:
    """Radial darkening from center to edges using Catppuccin crust color."""
    W, H = canvas.size
    cx, cy = W / 2, H / 2
    max_r = math.sqrt(cx ** 2 + cy ** 2)
    import numpy as np
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
    from PIL import ImageFilter
    import numpy as np
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
    import numpy as np
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
```

### Step 3: Update `make_wallpaper` — molecule size + star field + haze + effects

Find the `make_wallpaper` function. Make these changes:

**3a.** Change molecule target width from 0.22 to 0.28:
```python
# OLD:
target_w = int(W * 0.22)
# NEW:
target_w = int(W * 0.28)
```

**3b.** Before `canvas.paste(mol_scaled, ...)`, add star field and haze:
```python
    # Background star field (seeded per molecule name for stability)
    seed = hash(name) % (2 ** 31)
    canvas = draw_star_field(canvas, accent_hex, seed=seed, n_stars=300)

    # Soft accent haze at center
    canvas = draw_center_haze(canvas, accent_hex, opacity=0.10, radius_frac=0.30)

    canvas.paste(mol_scaled, (mol_x, mol_y), mol_scaled)
```

**3c.** After `draw.text(...)` at the end of `make_wallpaper`, add post-processing:
```python
    # Post-processing: vignette + glow bloom
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.28)

    return canvas
```

### Step 4: Visual test

```bash
python scripts/generate-molecule-wallpapers.py serotonin --preview
```

Open `images/wallpaper-rotation/catppuccin/molecule-serotonin-teal-preview.png`.

Expected: molecule is larger, faint star specks visible in background, soft teal glow around bonds, edges slightly darker than center.

### Step 5: Commit

```bash
git add scripts/generate-molecule-wallpapers.py
git commit -m "feat(wallpapers): cosmic ethereal — molecule glow, star field, haze, vignette"
```

---

## Task 2: Add utility helpers to science script + move `glow_dot` up

**Files:**
- Modify: `scripts/generate-science-wallpapers.py`

### Step 1: Add missing imports

At the top import block, ensure `import random` and `from PIL import ImageFilter` are present.
`math`, `numpy`, `PIL.Image`, `PIL.ImageDraw` are already imported.

### Step 2: Add `glow_dot` before the constellation section

Currently `glow_dot` is defined around line 477 (inside the orbital section). Move it to be defined right after the font helpers, around line 103 (after `add_label`). Cut it from its current location and paste it earlier:

```python
def glow_dot(ax, x, y, base_ms, accent_hex, accent01, zorder=4):
    """Draw a dot with soft glow by stacking translucent circles."""
    for mult, alpha in [(3.5, 0.06), (2.5, 0.10), (1.7, 0.18), (1.0, 0.90)]:
        ax.plot(x, y, "o", color=accent_hex, markersize=base_ms * mult,
                alpha=alpha, zorder=zorder, markeredgewidth=0)
```

### Step 3: Add the four utility functions after `fig_to_pil`

Same implementations as Task 1 Step 2, but now they reference the science script's `hex_to_rgb` / `hex_to_rgb01`. Paste them in verbatim — they are identical.

```python
# ─────────────────────────────────────────────
# Visual effects helpers
# ─────────────────────────────────────────────

def apply_vignette(canvas: Image.Image, strength: float = 0.25) -> Image.Image:
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
    from PIL import ImageFilter
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
```

### Step 4: Commit infrastructure

```bash
git add scripts/generate-science-wallpapers.py
git commit -m "feat(wallpapers): add visual effects helpers + move glow_dot to module scope"
```

---

## Task 3: Constellation improvements

**Files:**
- Modify: `scripts/generate-science-wallpapers.py` — `render_constellation` function

### Step 1: Use `glow_dot` for named stars

In `render_constellation`, find the named star rendering loop:
```python
    for sname, (sx, sy, srel) in stars.items():
        ms = max_marker * (0.4 + 0.6 * srel)
        ax.plot(sx, sy, "o", color=accent_hex, markersize=ms, zorder=3)
```

Replace with:
```python
    for sname, (sx, sy, srel) in stars.items():
        ms = max_marker * (0.4 + 0.6 * srel)
        glow_dot(ax, sx, sy, ms, accent_hex, accent01, zorder=3)
```

(`accent01` is already defined at the top of `render_constellation`.)

### Step 2: Increase connection line opacity

Find:
```python
    line_alpha = 0.5
```
Change to:
```python
    line_alpha = 0.65
```

### Step 3: Add haze + vignette + bloom after PIL canvas is built

After the existing `add_label(canvas, ...)` call, add:
```python
    canvas = draw_center_haze(canvas, accent_hex, opacity=0.08, radius_frac=0.45)
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.22)

    return canvas
```

Remove the bare `return canvas` that was there before.

### Step 4: Visual test

```bash
python scripts/generate-science-wallpapers.py --type constellation --name orion --preview
```

Expected: named stars have soft halos, lines slightly more visible, faint yellow ambient glow at center, subtle edge darkening.

### Step 5: Commit

```bash
git add scripts/generate-science-wallpapers.py
git commit -m "feat(wallpapers): constellation — glow stars, brighter lines, haze, vignette, bloom"
```

---

## Task 4: Orbital improvements

**Files:**
- Modify: `scripts/generate-science-wallpapers.py` — `render_orbital` function

### Step 1: Add background star field

After `fig.subplots_adjust(left=0, right=1, top=1, bottom=0)` and before the planet loop, render the matplotlib figure to PIL first... Actually the star field should be on the PIL canvas after matplotlib renders. So do it right after `canvas = Image.open(buf).convert("RGB")`:

```python
    canvas = canvas.resize((W, H), Image.LANCZOS)

    # Background star field (added in PIL, seeded by system name)
    seed = hash(sys_name) % (2 ** 31)
    canvas = draw_star_field(canvas, accent_hex, seed=seed, n_stars=250)
```

### Step 2: Add orbit trail arc around each planet

Inside the planet loop, right after the full orbit ellipse is drawn:
```python
        ax.plot(px, py, color=accent_hex, lw=orbit_lw, alpha=0.55, zorder=2)

        # Trail: short arc at higher opacity around planet position
        trail_hw = math.radians(20)
        trail_t = np.linspace(ang - trail_hw, ang + trail_hw, 40)
        trail_px = ex + a * np.cos(trail_t)
        trail_py = cy + b * np.sin(trail_t)
        ax.plot(trail_px, trail_py, color=accent_hex,
                lw=orbit_lw * 2.0, alpha=0.75, zorder=3)
```

### Step 3: Add haze + vignette + bloom

After `add_label(...)`, replace `return canvas` with:
```python
    canvas = draw_center_haze(canvas, accent_hex, opacity=0.10, radius_frac=0.38)
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.28)
    return canvas
```

### Step 4: Visual test

```bash
python scripts/generate-science-wallpapers.py --type orbital --name solar-system --preview
```

Expected: faint star field behind orbits, short bright arc near each planet, soft mauve center haze, glow bloom on planet/star dots.

### Step 5: Commit

```bash
git add scripts/generate-science-wallpapers.py
git commit -m "feat(wallpapers): orbital — star field, orbit trail, haze, vignette, bloom"
```

---

## Task 5: Feynman improvements

**Files:**
- Modify: `scripts/generate-science-wallpapers.py` — `render_feynman` + each `draw_*` function

### Step 1: Increase line weight and font size

In `render_feynman`, find:
```python
    lw = max(1.0, 2.0 * W / 3840)
    fs = max(7, 12 * W / 3840)
```

Change to:
```python
    lw = max(1.5, 3.2 * W / 3840)
    fs = max(9, 16 * W / 3840)
```

### Step 2: Replace vertex dots with `glow_dot` in each draw function

In each `draw_*` function, find vertex dot lines of the form:
```python
    ax.plot(vx, vy, 'o', color=accent_hex, markersize=5 * lw, zorder=6)
```
and:
```python
    for vx, vy in [vl, vr]:
        ax.plot(vx, vy, 'o', color=accent_hex, markersize=5 * lw, zorder=6)
```

Replace each with `glow_dot`. Each draw function receives `accent_hex` but not `accent01` — add it locally at the top of `render_feynman` and pass it through, or compute inline. Easiest: add `accent01` parameter to each `draw_*` function or just compute in render_feynman and pass as a kwarg.

Simplest approach — in `render_feynman`, compute `accent01` and pass it to `draw_fn`:
```python
    accent01 = hex_to_rgb01(accent_hex)
    draw_fn(ax, accent_hex, lw=lw, fs=fs, amp=amp, accent01=accent01)
```

Add `accent01` parameter to each `draw_*` function signature:
```python
def draw_electron_positron(ax, accent_hex, lw, fs, amp, accent01):
```
...etc for all five functions.

Then replace vertex dot calls:
```python
    # OLD
    ax.plot(vx, vy, 'o', color=accent_hex, markersize=5 * lw, zorder=6)
    # NEW
    glow_dot(ax, vx, vy, 5 * lw, accent_hex, accent01, zorder=6)
```

### Step 3: Add haze + vignette + bloom

In `render_feynman`, replace `return canvas` with:
```python
    canvas = draw_center_haze(canvas, accent_hex, opacity=0.08, radius_frac=0.40)
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.25)
    return canvas
```

### Step 4: Visual test

```bash
python scripts/generate-science-wallpapers.py --type feynman --name electron-positron --preview
```

Expected: thicker lines and labels, glowing vertex interaction points, soft peach center haze, ambient bloom.

### Step 5: Commit

```bash
git add scripts/generate-science-wallpapers.py
git commit -m "feat(wallpapers): feynman — thicker lines, glow vertices, haze, vignette, bloom"
```

---

## Task 6: Amino acid improvements

**Files:**
- Modify: `scripts/generate-science-wallpapers.py` — `make_aminoacid_wallpaper` function

### Step 1: Increase molecule size

Find:
```python
    target_w = int(W * 0.22)
```
Change to:
```python
    target_w = int(W * 0.28)
```

### Step 2: Add star field and haze before molecule paste

After `canvas = Image.new("RGB", (W, H), hex_to_rgb(BG_HEX))` and before the paste:
```python
    seed = hash(name) % (2 ** 31)
    canvas = draw_star_field(canvas, accent_hex, seed=seed, n_stars=300)
    canvas = draw_center_haze(canvas, accent_hex, opacity=0.10, radius_frac=0.30)

    canvas.paste(mol_scaled, (mol_x, mol_y), mol_scaled)
```

### Step 3: Add vignette + bloom after label

After `add_label(canvas, ...)`, replace `return canvas` with:
```python
    canvas = apply_vignette(canvas, strength=0.22)
    canvas = apply_glow_bloom(canvas, accent_hex, opacity=0.28)
    return canvas
```

### Step 4: Visual test

```bash
python scripts/generate-science-wallpapers.py --type aminoacid --name tryptophan --preview
```

Expected: matches molecule wallpaper style — larger structure, star field, mauve center glow, bloom.

### Step 5: Final full-batch preview

```bash
python scripts/generate-molecule-wallpapers.py --preview
python scripts/generate-science-wallpapers.py --preview
```

Check a few outputs from each type. Spot-check different accent colors (teal, mauve, peach, yellow) since the haze tint changes per accent.

### Step 6: Commit

```bash
git add scripts/generate-science-wallpapers.py
git commit -m "feat(wallpapers): amino acid — larger mol, star field, haze, vignette, bloom"
```

---

## Optional: Regenerate all production wallpapers

Once previews look good, regenerate at 4K:

```bash
python scripts/generate-molecule-wallpapers.py
python scripts/generate-science-wallpapers.py
```

Then commit the new images:

```bash
git add images/wallpaper-rotation/catppuccin/
git commit -m "chore(wallpapers): regenerate all with cosmic ethereal visual improvements"
```
