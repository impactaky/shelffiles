## Why

The nix-ai-tools input adds complexity to the flake for little benefit. Alternative tools like mise can handle AI tooling installation better, with simpler configuration and broader ecosystem support. Removing this simplifies maintenance.

## What Changes

- **BREAKING**: Remove `nix-ai-tools` input from `flake.nix`
- Simplify `packages.nix` function signature (remove `nix-ai-tools` parameter)
- Simplify `test/packages.nix` function signature (remove `nix-ai-tools` parameter)
- Update `openspec/project.md` documentation to remove nix-ai-tools references

## Impact

- Affected specs: None (no specs exist yet for nix-flake)
- Affected code: `flake.nix`, `packages.nix`, `test/packages.nix`, `openspec/project.md`
- Users relying on `nix-ai-tools` packages will need to use alternative installation methods (mise, direct nix package installation, etc.)
