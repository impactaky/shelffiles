# Cross-Compilation Guide

This guide explains how to build shelffiles packages for different architectures using Nix's cross-compilation capabilities.

## Overview

Cross-compilation allows you to build packages for a different architecture than your host system. For example:
- Build ARM (aarch64) packages on an x86_64 machine
- Build x86_64 packages on an ARM machine

This is particularly useful for:
- CI/CD pipelines that build for multiple deployment targets
- Developers preparing environments for different architectures
- Pre-building packages for servers running different architectures

## Quick Start

### Basic Usage

Build for a specific architecture using the `--system` flag:

```bash
# Build for ARM64/aarch64 on x86_64
./setup.sh --system aarch64-linux

# Build for x86_64 on ARM64
./setup.sh --system x86_64-linux

# Can be combined with other flags
./setup.sh --no-root --system aarch64-linux
```

### Docker-Based Cross-Compilation

```bash
# Cross-compile using Docker
./utils/build_nix_in_docker.sh --system aarch64-linux
```

## Supported Systems

The following target systems are supported:

- `x86_64-linux` - 64-bit x86 Linux
- `aarch64-linux` - 64-bit ARM Linux
- `x86_64-darwin` - 64-bit x86 macOS
- `aarch64-darwin` - 64-bit ARM macOS (Apple Silicon)

**Important Limitation**: Cross-compilation between different operating systems (Linux ↔ macOS) is not supported by Nix. You must use the same OS family.

Valid cross-compilation pairs:
- ✅ `x86_64-linux` ↔ `aarch64-linux`
- ✅ `x86_64-darwin` ↔ `aarch64-darwin`
- ❌ `x86_64-linux` → `aarch64-darwin` (OS mismatch)
- ❌ `aarch64-darwin` → `x86_64-linux` (OS mismatch)

## Prerequisites

### Linux Systems

For cross-compilation on Linux, you may need QEMU and binfmt_misc support to run binaries compiled for different architectures during the build process.

#### Ubuntu/Debian

```bash
sudo apt-get install qemu-user-static binfmt-support
```

#### Fedora/RHEL

```bash
sudo dnf install qemu-user-static
```

#### Arch Linux

```bash
sudo pacman -S qemu-user-static qemu-user-static-binfmt
```

#### Verify Setup

Check if binfmt_misc is enabled:

```bash
ls /proc/sys/fs/binfmt_misc/
# Should show qemu-* entries for different architectures
```

### macOS Systems

macOS with Apple Silicon already supports running x86_64 binaries through Rosetta 2, so no additional setup is typically required.

## Common Use Cases

### CI/CD Multi-Architecture Builds

Build for multiple architectures in your CI pipeline:

```bash
# In GitHub Actions, GitLab CI, etc.
./setup.sh --system x86_64-linux
./setup.sh --system aarch64-linux
```

Example GitHub Actions workflow:

```yaml
name: Build Multi-Arch
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        system: [x86_64-linux, aarch64-linux]
    steps:
      - uses: actions/checkout@v3
      - name: Install QEMU
        run: sudo apt-get install -y qemu-user-static binfmt-support
      - name: Build for ${{ matrix.system }}
        run: ./setup.sh --system ${{ matrix.system }}
```

### Pre-building for ARM Servers

Build ARM packages on your x86_64 development machine:

```bash
# Build for ARM deployment target
./setup.sh --system aarch64-linux

# Deploy result to ARM server
rsync -av result/ user@arm-server:/path/to/shelffiles/
```

### Local Testing

Test that your packages work across architectures:

```bash
# Build for both architectures
./setup.sh --system x86_64-linux
mv result result-x86_64

./setup.sh --system aarch64-linux
mv result result-aarch64

# Compare outputs, test in containers, etc.
```

## Performance Considerations

### Build Time

Cross-compilation using emulation (QEMU) is **significantly slower** than native builds:

- **Native builds**: Normal speed
- **Cross-compilation**: 2-10x slower (depending on package complexity)

For production CI/CD, consider using native builders for each architecture:
- Use native ARM runners for ARM builds
- Use native x86_64 runners for x86_64 builds

### Binary Caches

Nix's binary cache can help reduce build times:

```bash
# Use Nix's default cache
./setup.sh --system aarch64-linux \
  --option substituters "https://cache.nixos.org"

# Set up cachix for your team
cachix use <your-cache>
./setup.sh --system aarch64-linux
```

## Troubleshooting

### Error: "Unsupported system"

```
Error: Unsupported system 'arm-linux'
Supported systems: aarch64-linux x86_64-linux aarch64-darwin x86_64-darwin
```

**Solution**: Use the exact system names listed. For ARM, use `aarch64-linux`, not `arm-linux`.

### Error: "Cross-compilation between different operating systems is not supported"

```
Error: Cross-compilation between different operating systems (linux -> darwin) is not supported by Nix
```

**Solution**: You cannot cross-compile between Linux and macOS. Use a native builder for the target OS.

### Build Fails with "cannot execute binary file"

**Cause**: Missing QEMU/binfmt_misc support.

**Solution**: Install QEMU user-mode static and verify binfmt_misc is configured:

```bash
# Install QEMU
sudo apt-get install qemu-user-static binfmt-support

# Verify
ls /proc/sys/fs/binfmt_misc/
cat /proc/sys/fs/binfmt_misc/qemu-aarch64  # Should show "enabled"
```

### Package Fails to Cross-Compile

**Cause**: Not all Nix packages support cross-compilation cleanly. Some packages have architecture-specific dependencies or build scripts.

**Solutions**:

1. **Check package documentation**: Some packages document cross-compilation limitations
2. **Exclude the problematic package**: Edit `packages.nix` and comment out the package
3. **Use a native builder**: For critical packages, use a native build environment
4. **Report upstream**: File an issue with the Nix package maintainers

### Slow Builds

**Cause**: QEMU emulation overhead.

**Solutions**:

1. **Use binary caches**: Enable Nix's cache to avoid rebuilding packages
2. **Use native builders**: Switch to ARM hardware for ARM builds
3. **Build incrementally**: Cache intermediate build results
4. **Limit parallelism**: Reduce build parallelism to avoid memory pressure:

```bash
./setup.sh --system aarch64-linux --cores 2
```

## Advanced Usage

### Custom Nix Arguments

Pass additional arguments to the underlying `nix build` command:

```bash
# Increase verbosity
./setup.sh --system aarch64-linux --verbose

# Use specific cores
./setup.sh --system aarch64-linux --cores 4

# Keep build directory on failure
./setup.sh --system aarch64-linux --keep-failed
```

### Verifying Cross-Compiled Binaries

Check the architecture of built binaries:

```bash
# Build for ARM
./setup.sh --system aarch64-linux

# Check binary architecture
file result/bin/some-binary
# Output: ELF 64-bit LSB executable, ARM aarch64, ...

# On x86_64 Linux with QEMU:
result/bin/some-binary --version
# Should run through QEMU emulation
```

## References

- [Nix Cross-Compilation](https://nixos.wiki/wiki/Cross_Compiling)
- [Nix Flakes Manual](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html)
- [QEMU User Mode](https://www.qemu.org/docs/master/user/main.html)
- [binfmt_misc Documentation](https://docs.kernel.org/admin-guide/binfmt-misc.html)
