# Wallpaper Visual Improvements — Cosmic Ethereal (Approach B)

**Date:** 2026-03-09
**Branch:** feat/multi-theme
**Scripts affected:** `scripts/generate-molecule-wallpapers.py`, `scripts/generate-science-wallpapers.py`

---

## Goal

Elevate the generated Catppuccin Mocha wallpapers from flat/sparse to soft cosmic/ethereal,
matching the dreamy desktop aesthetic without departing from minimalism.

---

## Shared Post-Processing (both scripts)

Two reusable PIL utility functions added near the top of each script:

### `apply_vignette(canvas, strength=0.25)`
- Creates a radial gradient mask: center transparent → edges `#11111b` (crust)
- Drawn as an RGBA overlay composited onto the RGB canvas
- Subtle framing effect, does not change the subject itself

### `apply_glow_bloom(canvas, accent_hex, blur_radius=80, opacity=0.30)`
- Gaussian-blurs a copy of the canvas (radius 80px at 4K, scales with preview)
- Tints the blurred layer toward the accent color
- Composites it back at `opacity` using screen-like blending (add, clamped)
- Result: bonds/stars/lines appear to emit soft ambient light

Both functions are called as the final step in every `make_wallpaper` / `render_*` function,
after all content has been drawn.

---

## Per-Type Changes

### Molecule & Amino Acid
- Molecule target width: `0.22 → 0.28` of canvas width
- Add faint background star field: 300 random dots, same accent color, alpha 0.06–0.18,
  seeded with `random.Random(hash(name) % 2**31)` for per-molecule stability
- Soft radial accent haze: small radial gradient at canvas center, accent color at ~12% opacity,
  fading to 0% at ~35% of canvas radius
- Vignette + glow bloom applied last

### Constellation
- Named star dots: replace `ax.plot(..., "o")` with `glow_dot()` (already defined in orbitals)
  → copy `glow_dot` helper into the science script's constellation section
- Connection line alpha: `0.50 → 0.65`
- Faint radial accent haze at center (same as molecules, accent = yellow)
- Vignette + glow bloom applied last

### Orbital
- Add faint background star field: 300 dots, white/accent, alpha 0.05–0.15, seeded stable
- Orbit trail: at each planet's angular position, paint a secondary arc of ±20° at 2× the
  base orbit opacity, creating a subtle "trail" highlight
- Faint radial accent haze at center (accent = mauve)
- Vignette + glow bloom applied last
- (Planet/star glow_dot already in place — no change needed)

### Feynman
- Diagram scale up: reduce margins so diagram occupies more of the canvas
  (currently very small relative to 4K canvas)
- Vertex dots: replace `ax.plot(..., "o")` with `glow_dot()` inline
- Faint radial accent haze at center (accent = peach)
- Vignette + glow bloom applied last

---

## Non-Goals

- No color scheme changes — all colors remain exact Catppuccin Mocha hex values
- No new molecule/constellation/system definitions
- No changes to CLI interface or output filenames
- No dependency additions — only PIL (already used), numpy (already used)
