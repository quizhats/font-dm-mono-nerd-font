#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: package.sh <version>   e.g. package.sh 1.0.0}"
OUT_DIR="${OUT_DIR:-$(pwd)/out}"
DIST_DIR="${DIST_DIR:-$(pwd)/dist}"
ZIP_NAME="DMMonoNerdFont-v${VERSION}.zip"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Loose TTFs as convenience assets.
cp "$OUT_DIR"/*.ttf "$DIST_DIR"/

# Single combined zip of all patched TTFs (both flavors, all weights).
( cd "$OUT_DIR" && zip -q -r "$DIST_DIR/$ZIP_NAME" . -i '*.ttf' )

# Checksum (shasum is present on macOS and the GitHub ubuntu runner).
( cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256" )

echo "Packaged $ZIP_NAME"
cat "$DIST_DIR/$ZIP_NAME.sha256"
