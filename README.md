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

Patching uses the pinned `nerdfonts/patcher:v3.4.0` image.

## Releasing

Push a `vX.Y.Z` tag. CI patches, packages, creates the GitHub Release, and
opens a cask-bump PR against `quizhats/homebrew-fonts`.

## License

Fonts: SIL Open Font License 1.1 (see `src/OFL.txt`). DM Mono is a trademark of
its respective owners; the patched build is renamed "DM Mono Nerd Font" per the
OFL Reserved Font Name clause. Build scripts: MIT (see `LICENSE`).
