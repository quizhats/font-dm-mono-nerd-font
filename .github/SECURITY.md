# Security Policy

## Reporting a vulnerability

Please report security issues **privately** using GitHub's
[private vulnerability reporting](https://github.com/quizhats/font-dm-mono-nerd-font/security/advisories/new)
(the "Report a vulnerability" button on the Security tab). Do not open a public
issue for security problems.

We aim to acknowledge a report within a few days.

## Scope

This project patches Google's DM Mono with Nerd Fonts glyphs and publishes it via
GitHub Releases and a Homebrew tap. In-scope concerns include:

- Integrity of the release artifacts. Each release carries a build-provenance
  attestation; verify it with
  `gh attestation verify <file> --repo quizhats/font-dm-mono-nerd-font`.
- The build, release, and tap-update workflows.

The upstream DM Mono font and the Nerd Fonts patcher are maintained elsewhere;
report issues in those to their respective projects.
