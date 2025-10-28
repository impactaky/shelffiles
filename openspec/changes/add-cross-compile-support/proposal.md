# Cross-Compilation Support Proposal

## Why

Currently, shelffiles can only build packages for the host architecture. Users running x86_64 Linux cannot build aarch64 Linux packages without manual Nix configuration. This limits the ability to pre-build environments for deployment on different architectures (e.g., building ARM packages on x86_64 CI/CD systems for deployment to ARM servers).

## What Changes

- Add support for cross-compilation via `--system` flag to build commands
- Enable building aarch64-linux packages on x86_64-linux hosts (and vice versa)
- Leverage Nix's built-in cross-compilation capabilities
- Document cross-compilation workflows and limitations

## Impact

- **Affected specs**: `nix-build` (new capability)
- **Affected code**:
  - `flake.nix` - Already supports multiple systems
  - `setup.sh` - May need flag to specify target system
  - Build scripts and documentation
- **Benefits**:
  - Enable CI/CD systems to build for multiple architectures
  - Support pre-building environments for different deployment targets
  - Improve developer workflow for multi-architecture projects
