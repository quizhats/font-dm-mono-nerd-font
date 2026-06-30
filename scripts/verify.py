#!/usr/bin/env python3
"""Verify patched Nerd Font output: exactly 12 TTFs, each a Nerd Font family."""
import sys, glob, os
from fontTools.ttLib import TTFont

out_dir = sys.argv[1] if len(sys.argv) > 1 else "out"
ttfs = sorted(glob.glob(os.path.join(out_dir, "*.ttf")))

assert len(ttfs) == 12, f"expected 12 patched TTFs in {out_dir!r}, got {len(ttfs)}"

for path in ttfs:
    font = TTFont(path)
    family = font["name"].getDebugName(1) or ""
    assert "Nerd Font" in family, f"{path}: family {family!r} is missing 'Nerd Font'"

print(f"OK: {len(ttfs)} patched TTFs, all Nerd Font families")
