# DM Mono Nerd Font Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Nerd Fonts-patched DM Mono and publish it as versioned GitHub Releases, with a personal Homebrew tap cask that installs from those releases.

**Architecture:** Vendor the 6 upstream DM Mono TTFs in `src/`. A shell script patches them with the official `nerdfonts/patcher` Docker image into Standard + Mono flavors. A second script zips the output and emits a checksum. GitHub Actions smoke-tests on PRs and, on a `v*` tag, builds, creates the Release, and opens a cask-bump PR against the separate tap repo `quizhats/homebrew-fonts`.

**Tech Stack:** Bash, Docker (`nerdfonts/patcher:4.22.1`), Python `fonttools` (verification only), GitHub Actions, Homebrew Cask (Ruby).

## Global Constraints

- Patcher image pinned: `nerdfonts/patcher:4.22.1` (never `:latest`).
- Sources vendored from `google/fonts` `main` branch, path `ofl/dmmono/`: the 6 static TTFs (`DMMono-Light`, `DMMono-LightItalic`, `DMMono-Regular`, `DMMono-Italic`, `DMMono-Medium`, `DMMono-MediumItalic`) plus `OFL.txt`. The fonts stay OFL-1.1.
- Two flavors per weight: Standard = `--complete --careful`; Mono = `--complete --careful --mono`. 6 weights x 2 flavors = 12 patched TTFs.
- Patched family names must contain "Nerd Font" (OFL Reserved Font Name rename; the patcher does this).
- Release version = the git tag with the leading `v` stripped (`v1.2.3` -> `1.2.3`).
- Tap repo: `quizhats/homebrew-fonts`; install UX `brew tap quizhats/fonts && brew install --cask font-dm-mono-nerd-font`.
- Commits: GPG-signed (`git commit -S`), Conventional Commits.
- No em-dashes or en-dashes in any prose, comment, or commit message. Plain hyphens only.

---

### Task 1: Repo scaffolding, vendored sources, license

**Files:**
- Create: `.gitignore`
- Create: `LICENSE` (MIT, covers the build tooling)
- Create: `src/OFL.txt` (downloaded; governs the fonts)
- Create: `src/DMMono-Light.ttf`, `src/DMMono-LightItalic.ttf`, `src/DMMono-Regular.ttf`, `src/DMMono-Italic.ttf`, `src/DMMono-Medium.ttf`, `src/DMMono-MediumItalic.ttf` (downloaded)
- Create: `scripts/verify.py`

**Interfaces:**
- Produces: `src/*.ttf` (6 unpatched DM Mono fonts) consumed by `patch.sh` in Task 2; `scripts/verify.py` (a CLI: `python3 scripts/verify.py [out_dir]`) consumed by Tasks 2, 4, 5.

- [ ] **Step 1: Create `.gitignore`**

```gitignore
out/
dist/
__pycache__/
*.pyc
```

- [ ] **Step 2: Create `LICENSE` (MIT for tooling)**

Use a standard MIT license text with copyright line `Copyright (c) 2026 quizhats`. Add a one-line note at the top:

```
This MIT license covers the build scripts and configuration in this repository.
The fonts in src/ and all patched output are licensed under the SIL Open Font
License 1.1; see src/OFL.txt.
```

- [ ] **Step 3: Download the vendored sources**

Run:

```bash
mkdir -p src
base="https://raw.githubusercontent.com/google/fonts/main/ofl/dmmono"
for f in DMMono-Light.ttf DMMono-LightItalic.ttf DMMono-Regular.ttf \
         DMMono-Italic.ttf DMMono-Medium.ttf DMMono-MediumItalic.ttf OFL.txt; do
  curl -fsSL "$base/$f" -o "src/$f"
done
```

- [ ] **Step 4: Write `scripts/verify.py`**

```python
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
```

- [ ] **Step 5: Verify the sources downloaded and parse**

Run:

```bash
python3 -m pip install --quiet fonttools
ls src/*.ttf | wc -l
python3 - <<'PY'
import glob
from fontTools.ttLib import TTFont
ttfs = glob.glob("src/*.ttf")
assert len(ttfs) == 6, f"expected 6 source TTFs, got {len(ttfs)}"
for p in ttfs:
    fam = TTFont(p)["name"].getDebugName(1)
    assert fam and "DM Mono" in fam, f"{p}: unexpected family {fam!r}"
print("OK: 6 DM Mono sources")
PY
```

Expected: prints `6` then `OK: 6 DM Mono sources`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore LICENSE src scripts/verify.py
git commit -S -m "feat: vendor DM Mono sources and add output verifier"
```

---

### Task 2: Patch script

**Files:**
- Create: `scripts/patch.sh`

**Interfaces:**
- Consumes: `src/*.ttf` (Task 1), `scripts/verify.py` (Task 1).
- Produces: `scripts/patch.sh` writing 12 patched TTFs to `out/`; consumed by `package.sh` (Task 3), `ci.yml` (Task 4), `release.yml` (Task 5). Honors env overrides `SRC_DIR`, `OUT_DIR`.

- [ ] **Step 1: Write the verification first (define the expected outcome)**

The test is `scripts/verify.py` from Task 1 run against `out/`. There is no `out/` yet, so it must fail. Confirm the failing state:

Run: `python3 scripts/verify.py out`
Expected: FAIL with `AssertionError: expected 12 patched TTFs in 'out', got 0` (glob on a missing dir yields 0).

- [ ] **Step 2: Write `scripts/patch.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Patch DM Mono with Nerd Fonts glyphs in two flavors. Requires Docker.
# Standard -> "DM Mono Nerd Font" (icons up to double-width)
# Mono     -> "DM Mono Nerd Font Mono" (all glyphs single-width)

PATCHER_IMAGE="nerdfonts/patcher:4.22.1"
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
```

- [ ] **Step 3: Make it executable**

Run: `chmod +x scripts/patch.sh`

- [ ] **Step 4: Run the patcher**

Run: `./scripts/patch.sh`
Expected: pulls `nerdfonts/patcher:4.22.1` on first run, prints `Patched TTFs produced: 12`.

- [ ] **Step 5: Run verification and confirm it passes**

Run: `python3 scripts/verify.py out`
Expected: `OK: 12 patched TTFs, all Nerd Font families`

- [ ] **Step 6: Record the actual output filenames (needed for the cask in Task 6)**

Run: `ls out/ | sort`
Save this list; Task 6 creates one cask `font` stanza per file.

- [ ] **Step 7: Commit**

```bash
git add scripts/patch.sh
git commit -S -m "feat: patch DM Mono into Standard and Mono Nerd Font flavors"
```

---

### Task 3: Packaging script

**Files:**
- Create: `scripts/package.sh`

**Interfaces:**
- Consumes: `out/*.ttf` (Task 2).
- Produces: `dist/DMMonoNerdFont-v<version>.zip`, `dist/DMMonoNerdFont-v<version>.zip.sha256`, and loose `dist/*.ttf`. The zip name and sha file are consumed by `release.yml` (Task 5) and the cask `url` (Task 6). Takes `<version>` as `$1`; honors env overrides `OUT_DIR`, `DIST_DIR`.

- [ ] **Step 1: Write `scripts/package.sh`**

```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/package.sh`

- [ ] **Step 3: Run it against the patched output**

Run: `./scripts/package.sh 0.0.0-test`
Expected: prints `Packaged DMMonoNerdFont-v0.0.0-test.zip` and a sha256 line.

- [ ] **Step 4: Verify the package contents**

Run:

```bash
test -f dist/DMMonoNerdFont-v0.0.0-test.zip.sha256
unzip -l dist/DMMonoNerdFont-v0.0.0-test.zip | grep -c '\.ttf$'
ls dist/*.ttf | wc -l
```

Expected: the sha file exists; both counts are `12`.

- [ ] **Step 5: Commit**

```bash
git add scripts/package.sh
git commit -S -m "feat: package patched fonts into release zip with checksum"
```

---

### Task 4: CI smoke-test workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `scripts/patch.sh`, `scripts/verify.py`.
- Produces: a PR/push workflow that proves the build still works. No publishing.

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  patch-smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Patch fonts
        run: ./scripts/patch.sh

      - name: Verify patched output
        run: |
          python3 -m pip install --quiet fonttools
          python3 scripts/verify.py out
```

- [ ] **Step 2: Lint the workflow**

Run:

```bash
docker run --rm -v "$(pwd):/repo" -w /repo rhysd/actionlint:latest -color
```

Expected: no errors (exit 0). If `docker` is unavailable locally, instead install actionlint via `brew install actionlint` and run `actionlint`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -S -m "ci: smoke-test font patching on PRs and main"
```

---

### Task 5: Release + tap-bump workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `scripts/patch.sh`, `scripts/verify.py`, `scripts/package.sh`.
- Produces: on `v*` tag, a GitHub Release with the zip + sha256 + loose TTFs, then a cask-bump PR against `quizhats/homebrew-fonts`. Requires repo secret `TAP_PAT` (a PAT with `repo` scope on the tap) for the second job.

- [ ] **Step 1: Write `.github/workflows/release.yml`**

```yaml
name: release

on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  build-release:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      sha256: ${{ steps.checksum.outputs.sha256 }}
    steps:
      - uses: actions/checkout@v4

      - id: version
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - name: Patch fonts
        run: ./scripts/patch.sh

      - name: Verify patched output
        run: |
          python3 -m pip install --quiet fonttools
          python3 scripts/verify.py out

      - name: Package
        run: ./scripts/package.sh "${{ steps.version.outputs.version }}"

      - id: checksum
        run: |
          file="dist/DMMonoNerdFont-v${{ steps.version.outputs.version }}.zip.sha256"
          echo "sha256=$(cut -d' ' -f1 "$file")" >> "$GITHUB_OUTPUT"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            dist/*.zip
            dist/*.sha256
            dist/*.ttf

  update-tap:
    needs: build-release
    runs-on: ubuntu-latest
    steps:
      - name: Open cask-bump PR in the tap
        env:
          GH_TOKEN: ${{ secrets.TAP_PAT }}
          VERSION: ${{ needs.build-release.outputs.version }}
          SHA256: ${{ needs.build-release.outputs.sha256 }}
        run: |
          set -euo pipefail
          gh repo clone quizhats/homebrew-fonts tap
          cd tap
          cask="Casks/font-dm-mono-nerd-font.rb"
          sed -i -E "s/^(  version )\".*\"/\1\"${VERSION}\"/" "$cask"
          sed -i -E "s/^(  sha256 )\".*\"/\1\"${SHA256}\"/" "$cask"
          branch="bump-dm-mono-${VERSION}"
          git switch -c "$branch"
          git -c user.name="github-actions[bot]" \
              -c user.email="github-actions[bot]@users.noreply.github.com" \
              commit -am "feat: update font-dm-mono-nerd-font to ${VERSION}"
          git push -u origin "$branch"
          gh pr create --fill --base main --head "$branch"
```

- [ ] **Step 2: Lint the workflow**

Run:

```bash
docker run --rm -v "$(pwd):/repo" -w /repo rhysd/actionlint:latest -color
```

Expected: no errors. (`shellcheck` warnings from actionlint on the `run` blocks should be clean; fix any it reports.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -S -m "ci: build release and open tap cask-bump PR on tag"
```

---

### Task 6: Reference cask + README

**Files:**
- Create: `Casks/font-dm-mono-nerd-font.rb`
- Create: `README.md`

**Interfaces:**
- Consumes: the actual `out/` filenames recorded in Task 2 Step 6, and the release `url`/`sha256` shape from Tasks 3 and 5.
- Produces: the reference cask (the live copy is bumped by `release.yml` into the tap) and user-facing docs.

- [ ] **Step 1: Write `Casks/font-dm-mono-nerd-font.rb`**

Create one `font` stanza per file from Task 2 Step 6's `ls out/`. The names below are the expected `--makegroups` output; replace them with the actual listing if they differ.

```ruby
cask "font-dm-mono-nerd-font" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/quizhats/font-dm-mono-nerd-font/releases/download/v#{version}/DMMonoNerdFont-v#{version}.zip"
  name "DM Mono Nerd Font"
  desc "DM Mono patched with Nerd Fonts glyphs"
  homepage "https://github.com/quizhats/font-dm-mono-nerd-font"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Standard flavor
  font "DMMonoNerdFont-Regular.ttf"
  font "DMMonoNerdFont-Italic.ttf"
  font "DMMonoNerdFont-Light.ttf"
  font "DMMonoNerdFont-LightItalic.ttf"
  font "DMMonoNerdFont-Medium.ttf"
  font "DMMonoNerdFont-MediumItalic.ttf"

  # Mono flavor
  font "DMMonoNerdFontMono-Regular.ttf"
  font "DMMonoNerdFontMono-Italic.ttf"
  font "DMMonoNerdFontMono-Light.ttf"
  font "DMMonoNerdFontMono-LightItalic.ttf"
  font "DMMonoNerdFontMono-Medium.ttf"
  font "DMMonoNerdFontMono-MediumItalic.ttf"
end
```

- [ ] **Step 2: Reconcile the cask `font` stanzas with the real output**

Run: `ls out/ | sort`
Edit the cask so there is exactly one `font "<name>.ttf"` line per listed file (12 total). The `version`/`sha256` stay as the `0.0.0` / zero placeholder here; the tap's live copy is filled by `release.yml`.

- [ ] **Step 3: Write `README.md`**

```markdown
# DM Mono Nerd Font

[DM Mono](https://fonts.google.com/specimen/DM+Mono) patched with
[Nerd Fonts](https://www.nerdfonts.com/) glyphs (icons from Font Awesome,
Devicons, Powerline, Octicons, and more).

Two flavors per weight:

- **DM Mono Nerd Font** - icons may render up to double-width (editors, UI).
- **DM Mono Nerd Font Mono** - every icon forced to a single cell (terminals).

## Install (Homebrew)

```sh
brew tap quizhats/fonts
brew install --cask font-dm-mono-nerd-font
```

## Install (manual)

Download the latest `DMMonoNerdFont-v*.zip` from
[Releases](https://github.com/quizhats/font-dm-mono-nerd-font/releases),
unzip, and install the TTFs.

## Build it yourself

Requires Docker.

```sh
./scripts/patch.sh                 # -> out/*.ttf (12 files)
./scripts/package.sh 1.0.0         # -> dist/ zip + sha256
```

Patching uses the pinned `nerdfonts/patcher:4.22.1` image.

## Releasing

Push a `vX.Y.Z` tag. CI patches, packages, creates the GitHub Release, and
opens a cask-bump PR against `quizhats/homebrew-fonts`.

## License

Fonts: SIL Open Font License 1.1 (see `src/OFL.txt`). DM Mono is a trademark of
its respective owners; the patched build is renamed "DM Mono Nerd Font" per the
OFL Reserved Font Name clause. Build scripts: MIT (see `LICENSE`).
```

- [ ] **Step 4: Validate the cask (if Homebrew is available)**

Run: `brew style --cask Casks/font-dm-mono-nerd-font.rb`
Expected: no offenses. (Skip if `brew` is not installed locally; CI in the tap repo will catch style issues.)

- [ ] **Step 5: Commit**

```bash
git add Casks/font-dm-mono-nerd-font.rb README.md
git commit -S -m "feat: add reference cask and README"
```

---

## Post-plan manual prerequisites (one-time, outside this repo)

These are not code tasks but are required before the release workflow's tap-bump job succeeds:

1. Create the tap repo `quizhats/homebrew-fonts` (an empty repo named `homebrew-fonts`).
2. Add `Casks/font-dm-mono-nerd-font.rb` to it (copy this repo's reference cask).
3. In `quizhats/font-dm-mono-nerd-font` settings, add secret `TAP_PAT` = a PAT with `repo` scope on the tap.

## Self-review notes

- Spec coverage: vendored sources (T1), Docker patch both flavors (T2), zip+sha256 (T3), CI smoke test (T4), tag release + tap auto-PR (T5), reference cask + docs (T6), tap prerequisites (post-plan). All spec sections map to a task.
- The only intentionally deferred value is the exact patched TTF filenames, which depend on `--makegroups` output and are reconciled against `ls out/` in T2 Step 6 and T6 Step 2.
