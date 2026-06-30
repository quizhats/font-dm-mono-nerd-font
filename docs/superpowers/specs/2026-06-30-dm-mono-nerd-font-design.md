# DM Mono Nerd Font — Design

Date: 2026-06-30
Status: Approved (pending spec review)

## Goal

Produce and publish a Nerd Fonts–patched build of Google's **DM Mono** (which is not
in the official Nerd Fonts collection). Distribute via a versioned **GitHub Release**
(source of truth) and a **Homebrew tap cask** that points at the Release assets.

## Inputs and licensing

- Upstream: DM Mono, 6 static TTFs — Light, Regular, Medium, each with an Italic.
- License: OFL-1.1. The Reserved Font Name clause requires the patched output be
  renamed; `font-patcher` renames it to "DM Mono Nerd Font", so the build is
  license-clean by construction. Upstream `OFL.txt` is vendored verbatim in `src/`.

## Distribution targets

1. **GitHub Release** on `quizhats/font-dm-mono-nerd-font` — the canonical artifact.
2. **Homebrew cask** in a separate tap repo `quizhats/homebrew-fonts` (a tap must be a
   repo named `homebrew-*`; it cannot be tapped from this repo). Install UX:
   `brew tap quizhats/fonts && brew install --cask font-dm-mono-nerd-font`.

## Repository layout

```
font-dm-mono-nerd-font/
├── src/                          # vendored upstream DM Mono (OFL)
│   ├── DMMono-Light.ttf  DMMono-LightItalic.ttf
│   ├── DMMono-Regular.ttf  DMMono-Italic.ttf
│   ├── DMMono-Medium.ttf  DMMono-MediumItalic.ttf
│   └── OFL.txt
├── scripts/
│   ├── patch.sh                  # run nerdfonts/patcher over src/ → dist/
│   └── package.sh                # zip dist/ + emit sha256
├── Casks/
│   └── font-dm-mono-nerd-font.rb # reference copy of the cask
├── .github/workflows/
│   ├── ci.yml                    # PR/push: patch smoke-test, no publish
│   └── release.yml               # tag v*: patch → package → Release → tap PR
├── README.md
└── LICENSE
```

## Build pipeline

Patching uses the official **`nerdfonts/patcher`** Docker image, **pinned** to an
explicit version tag (e.g. `nerdfonts/patcher:v3.4.0`; exact tag verified during
implementation). No local FontForge required.

`scripts/patch.sh` runs the image twice over `src/`:

- Standard flavor → `dist/standard/`: `--complete --careful`
  → family "DM Mono Nerd Font" (icons may be up to double-width).
- Mono flavor → `dist/mono/`: `--complete --mono --careful`
  → family "DM Mono Nerd Font Mono" (all icons forced single-cell).

`--careful` avoids overwriting glyphs already present in DM Mono. Result: 6 weights ×
2 flavors = 12 patched TTFs. (Exact docker volume-mount invocation and flag names are
confirmed against the patcher docs in the implementation plan.)

`scripts/package.sh`:

- Collects all patched TTFs into one release asset `DMMonoNerdFont-v<version>.zip`.
- Also emits the loose TTFs as convenience assets.
- Writes `DMMonoNerdFont-v<version>.zip.sha256`.

## CI/CD

- **`ci.yml`** (PR + push to main): runs `patch.sh` as a smoke test to prove the build
  still works on the current sources/patcher. Publishes nothing.
- **`release.yml`** (trigger: push of a `v*` tag):
  1. `patch.sh` → `package.sh`.
  2. Create the GitHub Release for the tag; upload the zip, loose TTFs, and `.sha256`.
  3. Compute the zip's sha256 and open a PR against `quizhats/homebrew-fonts`
     updating the cask's `version` and `sha256` (uses a `TAP_PAT` repo secret).

## Homebrew cask

`Casks/font-dm-mono-nerd-font.rb` is the reference; the live copy lives in the tap.
Shape:

```ruby
cask "font-dm-mono-nerd-font" do
  version "1.0.0"
  sha256 "<zip sha256>"
  url "https://github.com/quizhats/font-dm-mono-nerd-font/releases/download/v#{version}/DMMonoNerdFont-v#{version}.zip"
  name "DM Mono Nerd Font"
  desc "DM Mono patched with Nerd Fonts glyphs"
  homepage "https://github.com/quizhats/font-dm-mono-nerd-font"

  # one `font` stanza per patched TTF (both flavors, all weights)
  font "DMMonoNerdFont-Regular.ttf"
  # ... remaining weights + Mono-flavor files
end
```

(Final TTF filenames come from the patcher output and are filled in once a build runs.)

## Versioning

- Tag-driven: `vX.Y.Z` on this repo triggers a release.
- Release notes record the upstream DM Mono version and the pinned
  `nerdfonts/patcher` image tag, so every release maps to exact inputs.

## Why a personal tap and not official `homebrew/cask`

A new self-owned font cask cannot get into `homebrew/cask` directly:

- Notability: repos under 30 forks / 30 watchers / 75 stars are rejected as "too
  obscure"; for self-submitted casks (PR author owns the repo) the bar rises to
  90 forks / 90 watchers / 225 stars.
- Self-patched forks fall under "Unofficial, Vendorless, and Walled builds", which
  Homebrew does not accept, and "Cask is not a discoverability service".

Every official `font-*-nerd-font` cask exists only because the font is in the
official `ryanoasis/nerd-fonts` project (which is notable enough), whose releases
generate the casks. Getting DM Mono there means upstreaming it (see
[issue #1299](https://github.com/ryanoasis/nerd-fonts/issues/1299)) — maintainer-gated
and slow. We chose the self-controlled personal-tap route instead. Upstreaming
remains a possible later move; if it lands, this tap can be deprecated.

## Out of scope (v1)

- npm / Fontsource packaging.
- woff2/web font generation.
- Variable-font output (DM Mono ships only static instances).

## Open items to confirm during implementation

- Exact `nerdfonts/patcher` image tag and its precise CLI flags / mount layout.
- Exact patched TTF filenames the patcher emits (drives the cask `font` stanzas).
- Whether to also publish per-weight zips (default: single combined zip only).
