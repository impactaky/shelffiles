# Cross-Compilation Design

## Context

Shelffiles uses Nix flakes to build reproducible environments across multiple architectures. The flake.nix already defines outputs for all supported systems (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin). However, there's currently no user-facing interface to build for a different target architecture than the host system.

Cross-compilation is particularly valuable for:
- CI/CD pipelines building artifacts for deployment targets
- Developers preparing environments for different architectures
- Pre-building packages for ARM servers on x86_64 build machines

## Goals / Non-Goals

**Goals:**
- Enable cross-compilation of Linux packages (x86_64-linux ↔ aarch64-linux)
- Provide simple CLI interface via `--system` flag
- Leverage Nix's native cross-compilation support
- Document prerequisites and limitations clearly

**Non-Goals:**
- Cross-compilation between different operating systems (Linux ↔ Darwin) - Nix limitation
- Supporting architectures beyond those already in flake.nix
- Optimizing cross-compilation performance (use Nix's default behavior)
- Building custom cross-compilation toolchains

## Decisions

### Decision 1: Use Nix's Package Attribute Syntax

**Choice:** Use `nix build .#packages.<system>.default` syntax for cross-compilation

**Rationale:**
- Nix flakes already expose packages per system
- No modification to flake.nix required
- Transparent to users familiar with Nix
- Works with existing multi-system output structure

**Alternatives considered:**
1. **Modify flake to use `pkgsCross`** - More complex, requires flake restructuring
2. **Create separate cross-compilation flake** - Duplicates configuration, harder to maintain

### Decision 2: Add `--system` Flag to Build Commands

**Choice:** Extend `setup.sh` and build scripts with optional `--system TARGET` parameter

**Example usage:**
```bash
./setup.sh build --system aarch64-linux
nix build .#packages.aarch64-linux.default
```

**Rationale:**
- Consistent with Nix terminology
- Optional flag maintains backward compatibility
- Clear target system specification

**Alternatives considered:**
1. **Separate `cross-build` command** - Less discoverable, duplicates logic
2. **Environment variable (`TARGET_SYSTEM`)** - Less explicit, harder to document

### Decision 3: Prerequisites via Documentation, Not Enforcement

**Choice:** Document QEMU/binfmt requirements but don't enforce them in scripts

**Rationale:**
- Nix handles most cross-compilation transparently
- Some packages may build without emulation
- System setup varies by distribution
- Let Nix fail with meaningful errors rather than pre-checking

**Alternatives considered:**
1. **Pre-flight checks in scripts** - Complex, distribution-specific, may false-positive
2. **Bundle QEMU in environment** - Increases environment size, requires elevated privileges

## Technical Approach

### System Validation

Valid cross-compilation pairs for Linux:
- `x86_64-linux` → `aarch64-linux` ✓
- `aarch64-linux` → `x86_64-linux` ✓

Invalid pairs (warn user):
- `x86_64-linux` → `aarch64-darwin` ✗ (OS mismatch)
- Any `*-darwin` → `*-linux` ✗ (OS mismatch)

### Script Modifications

**setup.sh (argc-based):**
```bash
# Add to argc configuration
# @option --system <SYSTEM> Target system (e.g., aarch64-linux, x86_64-linux)

build() {
    local target_system="${argc_system:-$(nix eval --impure --expr 'builtins.currentSystem')}"
    nix build ".#packages.${target_system}.default"
}
```

**utils/build_nix_in_docker.sh:**
- Add `--build-arg TARGET_SYSTEM` parameter
- Pass to Nix build command inside container

### Error Handling

1. **Invalid system format** → Show valid options, exit 1
2. **Unsupported system** → Show supported systems from flake.nix, exit 1
3. **Cross-OS compilation** → Warn that Nix doesn't support this, exit 1
4. **Missing QEMU** → Let Nix error naturally with guidance in docs

## Risks / Trade-offs

### Risk: Build Time Increases
Cross-compilation via emulation is slower than native builds.

**Mitigation:**
- Document performance expectations
- Recommend native builders for production CI/CD
- Consider Nix binary cache for common packages

### Risk: Package Compatibility
Not all Nix packages support cross-compilation cleanly.

**Mitigation:**
- Test with shelffiles' default package set
- Document known incompatibilities in packages.nix comments
- Provide fallback guidance (use native builder, exclude package)

### Risk: User Confusion
Users may not understand when cross-compilation is needed vs. multi-arch flakes.

**Mitigation:**
- Clear documentation with use case examples
- Flake already builds for multiple systems natively
- Cross-compilation is opt-in feature for specific workflows

## Migration Plan

**Phase 1: Add Flag Support**
- Extend argc configuration in setup.sh
- Add `--system` parameter validation
- Update build commands to accept target system

**Phase 2: Documentation**
- Add CROSS_COMPILE.md guide
- Update README with cross-compilation examples
- Document QEMU/binfmt setup per distribution

**Phase 3: CI Integration**
- Add GitHub Actions workflow testing cross-compilation
- Build both x86_64 and aarch64 artifacts in CI
- Verify cross-compiled packages in test containers

**Rollback:**
- Remove `--system` flag from argc config
- Revert script changes
- No flake.nix changes needed (already multi-system)

## Open Questions

1. **Should we cache cross-compiled builds?**
   - Decision: Use Nix's default behavior, document how to set up cachix for teams

2. **Do we support cross-compiling the Docker fallback?**
   - Decision: Yes, via `--build-arg TARGET_SYSTEM` in Dockerfile, same pattern as Nix

3. **How do we handle packages that fail cross-compilation?**
   - Decision: Document in packages.nix comments, provide per-package opt-out mechanism if needed
