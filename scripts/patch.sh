#!/usr/bin/env bash
set -euo pipefail

# Patch DM Mono with Nerd Fonts glyphs in two flavors. Requires Docker.
# Standard -> "DM Mono Nerd Font" (icons up to double-width)
# Mono     -> "DM Mono Nerd Font Mono" (all glyphs single-width)

# Pinned by digest for reproducibility and supply-chain integrity.
# Digest is font-patcher image tag 4.22.1 (tag tracks the patcher version,
# not the nerd-fonts release number).
PATCHER_IMAGE="nerdfonts/patcher@sha256:5d7ffcb702a7c14eeda9b107f9dadd6d250dedf9d1f0993d966b4fd8337c47a6"
SRC_DIR="${SRC_DIR:-$(pwd)/src}"
OUT_DIR="${OUT_DIR:-$(pwd)/out}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# The patcher scans /in for font files; OFL.txt is ignored.
docker run --rm \
  -v "$SRC_DIR:/in:Z" \
  -v "$OUT_DIR:/out:Z" \
  "$PATCHER_IMAGE" --complete --careful

docker run --rm \
  -v "$SRC_DIR:/in:Z" \
  -v "$OUT_DIR:/out:Z" \
  "$PATCHER_IMAGE" --complete --careful --mono

count="$(find "$OUT_DIR" -name '*.ttf' | wc -l | tr -d ' ')"
echo "Patched TTFs produced: $count"
