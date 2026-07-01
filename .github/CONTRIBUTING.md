# Contributing

Thanks for your interest. This repo builds a Nerd Fonts-patched DM Mono and
publishes it via GitHub Releases and the `quizhats/homebrew-fonts` Homebrew tap.

## Building locally

Requires Docker.

```sh
./scripts/patch.sh              # patch src/ -> out/ (12 patched TTFs)
python3 -m pip install fonttools
python3 scripts/verify.py out   # assert 12 Nerd Font TTFs
./scripts/package.sh 0.0.0-dev  # zip + sha256 -> dist/
```

Do not commit patched output; `out/` and `dist/` are gitignored and CI builds them.

## Commit and PR conventions

- **Conventional Commits** for both messages and PR titles. PRs are
  **squash-merged**, and the squash commit uses the **PR title**, so the PR title
  itself must be a valid conventional commit (for example `fix: ...`, `ci: ...`).
- Commits must be **signed**; `main` requires signed commits.
- Branch names use conventional prefixes (`feat/`, `fix/`, `ci/`, `docs/`, ...).
- Keep workflows clean under `actionlint`, and pin every GitHub Action by full
  commit SHA (Dependabot keeps the pins current).

## Releases

Releases are automated with
[release-please](https://github.com/googleapis/release-please). Do not hand-edit
versions or push tags manually. Merging conventional commits into `main` maintains
a release PR that, when merged, tags the version and publishes the release (build,
verify, attest, upload) in one run.

## Good things to contribute

Bumping the pinned patcher image, adding a weight or flavor, or fixing the
build/release workflows.
