# Agent Guide

This is a Nix flake that packages Claude Code as a Bureau agent template. The
primary artifact is `flake.nix`, which composes an environment derivation and
exports a `bureauTemplate` attribute.

## Repository structure

- `flake.nix` — environment composition and Bureau template definition. Exports
  `packages.default` (the environment) and `bureauTemplate` (template attributes).
- `entry.sh` — minimal entry point script. Sets up the `.claude/` directory and
  execs `bureau-agent-claude`. This is scaffolding that will be absorbed into the
  Go binary when the Bureau SDK ships.
- `.github/workflows/ci.yaml` — builds the flake, validates the template output,
  and pushes to the R2 binary cache on merge to main.
- `README.md` — deployment guide for operators.

## Making changes

Edit `flake.nix` and/or `entry.sh`. Run `nix build` to verify it builds, and
`nix eval --json .#bureauTemplate.x86_64-linux` to verify the template output.
Run `shellcheck entry.sh` to lint the entry script. Update `flake.lock` with
`nix flake update` if changing inputs.

The `bureauTemplate` output must use snake_case field names matching Bureau's
`TemplateContent` JSON wire format. See the Bureau monorepo's
`lib/schema/events_template.go` for the full field list.
