#!/usr/bin/env python3
"""Map an arbitrary hex color to the nearest papirus-folders color name.

Usage:  papirus-nearest-color.py #RRGGBB
Output: the closest color name accepted by papirus-folders -C
"""

import math
import os
import re
import subprocess
import sys

PAPIRUS_PLACES = "/usr/share/icons/Papirus-Dark/16x16/places"
PAPIRUS_FOLDERS_BIN = os.path.expanduser("~/.local/bin/papirus-folders")


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def dist(a: str, b: str) -> float:
    ra, ga, ba = hex_to_rgb(a)
    rb, gb, bb = hex_to_rgb(b)
    return math.sqrt((ra - rb) ** 2 + (ga - gb) ** 2 + (ba - bb) ** 2)


def main_color(name: str) -> str | None:
    """Extract the most saturated (most folder-like) hex from a folder SVG."""
    svg = os.path.join(PAPIRUS_PLACES, f"folder-{name}.svg")
    if not os.path.isfile(svg):
        return None
    with open(svg, encoding="utf-8", errors="replace") as f:
        content = f.read()
    hexes = set(re.findall(r"#[0-9a-fA-F]{6}", content, re.I))
    best, best_sat = None, 0
    for h in hexes:
        r, g, b = hex_to_rgb(h)
        sat = max(r, g, b) - min(r, g, b)
        # skip near-grey, near-black, near-white
        bright = (r + g + b) / 3
        if sat < 30 or bright < 20 or bright > 230:
            continue
        if sat > best_sat:
            best_sat = sat
            best = h
    return best


def available_colors() -> list[tuple[str, str]]:
    """Return [(name, hex), …] for all Papirus-Dark folder color names."""
    try:
        result = subprocess.run(
            [PAPIRUS_FOLDERS_BIN, "-l", "-t", "Papirus-Dark"],
            capture_output=True, text=True, timeout=10,
        )
        names = [ln.strip() for ln in result.stdout.splitlines() if ln.strip()]
    except Exception:
        names = []
    pairs = []
    for name in names:
        c = main_color(name)
        if c:
            pairs.append((name, c))
    return pairs


def nearest(target: str, colors: list[tuple[str, str]]) -> str:
    if not colors:
        return "blue"
    return min(colors, key=lambda kv: dist(target, kv[1]))[0]


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "#cba6f7"
    colors = available_colors()
    print(nearest(target, colors))
