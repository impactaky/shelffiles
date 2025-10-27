# Project Context

## Purpose
Shelffiles is a portable environment configuration system that uses Nix to manage packages and configuration files. It provides a reproducible, XDG-compliant development environment that works consistently across different systems (Linux/macOS, x86_64/aarch64).

**Key Goals:**
- Provide a portable, version-controlled development environment
- Support XDG Base Directory specification for configuration management
- Enable multi-user environments without conflicts (via user/group-specific paths)

## Tech Stack
- **Nix Flakes** - Primary package management and reproducible builds
- **Shell scripting** - bash, zsh, fish
- **Bubblewrap** - Containerization fallback for isolated environments
- **https://github.com/sigoden/argcArgc** - CLI argument parsing framework
- **BATS** - Bash Automated Testing System for shell integration tests
- **Docker** - CI/CD testing environment and alternative build method
- **nix-portable** - Non-root Nix installation support

## Project Conventions

### Code Style
- **Shell scripts**: POSIX-compliant where possible, shellcheck-validated
- **Nix code**: Formatted with nixfmt (`nixfmt -c`)

### Architecture Patterns
**Three-Layer Architecture:**

1. **Nix Flakes Layer**
   - `flake.nix`: Defines multi-architecture package environment
   - `packages.nix`: User-customizable package list with nix-ai-tools support
   - Creates `generated_env.sh` with package-specific environment variables

2. **XDG Environment Management** (`entrypoint/env.sh`)
   - Sets XDG variables pointing to repository subdirectories
   - Auto-creates cache/, share/, state/ directories
   - To find XDG setting for tool, you can refer to [ARCH Linux wiki](https://wiki.archlinux.org/title/XDG_Base_Directory)

3. **Shell Integration Layer** (`entrypoint/{bash,zsh,fish}`)
   - Shell-specific launchers with appropriate variable settings
   - Falls back to `launch_in_bwrap.sh` when Nix unavailable

### Testing Strategy
**Test Framework:** BATS (Bash Automated Testing System)

**Test Coverage:**
- Shell loading tests: `bashrc_load.bats`, `zshrc_load.bats`, `fishrc_load.bats`
- Each test verifies correct config loading via environment variables
- Test configs set `SHELFFILES_*_TEST="loaded"` flags

**CI/CD Workflows:**
- **Docker Build**: Full integration test in clean environment
- **Lint**: Pre-commit hooks (shellcheck, hadolint, YAML, nixfmt)
- **Argc Verify**: Ensures setup.sh stays synced with argc generation
- **Claude Code**: AI assistant integration

### Git Workflow
- **Main branch**: `main` (used for PRs and production)
- **Commit conventions**: Standard semantic commits encouraged
- **Special filters**: Git filter configuration in `example/config/git/` to exclude "shelffiles" lines from devcontainer.json commits
- **Protected paths**: packages.nix may be added to .gitignore for private configs
- **CI triggers**: PRs trigger lint, Docker build, argc verification

## Domain Context
**Environment Management Concepts:**
- **XDG Base Directory Specification**: Standard for storing config/cache/data files
- **PATH_ID**: Unique identifier format `{SHELFFILES_path}_{USER_ID}_{GROUP_ID}` converted with `tr '/:' '__'`
- **Nix Store**: Immutable package storage, typically at /nix/store
- **Nix Flakes**: Modern Nix feature for reproducible package definitions
- **buildEnv**: Nix function that combines multiple packages into single environment
- **Bubblewrap**: Linux namespace sandboxing tool for containerization

**Multi-Shell Support:**
- Each shell has unique config loading mechanism
- Bash: sources ~/.bashrc
- Zsh: uses $ZDOTDIR for config location
- Fish: loads from XDG_CONFIG_HOME/fish/config.fish

## Important Constraints
**Technical Constraints:**
- `setup.sh` is argc-generated - do NOT manually edit argc-generated sections
- Regenerate setup.sh with: `argc --argc-build setup.sh > setup.sh`
- macOS does not support --no-root flag (nix-portable limitation)

**Platform Support:**
- Linux: x86_64, aarch64 (full support)
- macOS: x86_64, aarch64 (full support, no --no-root)

## External Dependencies
**Required Tools:**
- **Nix** : Package manager with flakes support
  - Flakes enabled via `--extra-experimental-features nix-command flakes`

**Optional/Fallback Tools:**
- **nix-portable**: Non-root Nix alternative (auto-installed by setup.sh --no-root)
  - Source: https://github.com/DavHau/nix-portable
- **Bubblewrap**: Namespace containerization (for launch_in_bwrap.sh)
- **Docker**: CI testing and alternative build method

**Build-time Dependencies:**
- **Argc**: CLI parsing framework for setup.sh
  - Source: https://github.com/sigoden/argc
- **BATS**: Testing framework for shell scripts
  - Included in packages.nix for test environments

**Package Sources:**
- **nixpkgs**: Primary package repository (nixos-unstable channel)
  - Search: https://search.nixos.org/packages
- **nix-ai-tools**: AI development tools integration
  - Source: https://github.com/numtide/nix-ai-tools
