# Nix Build Specification

## Requirements

### Requirement: Cross-Compilation Support

The build system SHALL support cross-compilation to different target architectures using Nix's native cross-compilation capabilities.

#### Scenario: Build for aarch64-linux on x86_64-linux host

- **WHEN** user runs build command with `--system aarch64-linux` on an x86_64-linux host
- **THEN** the system SHALL build packages for the aarch64-linux target architecture
- **AND** the build SHALL succeed if all packages support cross-compilation

#### Scenario: Build for x86_64-linux on aarch64-linux host

- **WHEN** user runs build command with `--system x86_64-linux` on an aarch64-linux host
- **THEN** the system SHALL build packages for the x86_64-linux target architecture
- **AND** the build SHALL succeed if all packages support cross-compilation

#### Scenario: Default to native architecture when no system specified

- **WHEN** user runs build command without `--system` flag
- **THEN** the system SHALL build for the current host architecture
- **AND** behavior SHALL remain unchanged from previous versions

### Requirement: System Validation

The build system SHALL validate target system specifications and prevent invalid cross-compilation attempts.

#### Scenario: Invalid system format provided

- **WHEN** user provides an invalid system format (e.g., `--system invalid`)
- **THEN** the system SHALL display an error message listing valid system formats
- **AND** the system SHALL exit with non-zero status code
- **AND** the error message SHALL include: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin

#### Scenario: Cross-OS compilation attempted

- **WHEN** user attempts to cross-compile between different operating systems (e.g., linux to darwin)
- **THEN** the system SHALL display a warning that cross-OS compilation is not supported by Nix
- **AND** the system SHALL exit with non-zero status code
- **AND** the error message SHALL suggest using a native builder for the target OS

#### Scenario: Unsupported architecture requested

- **WHEN** user specifies a target system not defined in flake.nix
- **THEN** the system SHALL display an error listing supported systems from flake configuration
- **AND** the system SHALL exit with non-zero status code

### Requirement: CLI Interface for Target System Selection

The setup script SHALL provide a command-line flag to specify the target compilation system.

#### Scenario: Using --system flag with setup.sh

- **WHEN** user runs `./setup.sh --system aarch64-linux`
- **THEN** the system SHALL pass the target system to the Nix build command
- **AND** the system SHALL build using `.#packages.aarch64-linux.default` attribute path

#### Scenario: Using --system flag with Docker build

- **WHEN** user runs Docker build script with `--system aarch64-linux`
- **THEN** the system SHALL pass TARGET_SYSTEM build argument to Docker
- **AND** Docker build SHALL use the specified system for Nix build commands

### Requirement: Documentation of Prerequisites

The system SHALL document prerequisites and limitations for cross-compilation.

#### Scenario: User reads cross-compilation documentation

- **WHEN** user consults cross-compilation documentation
- **THEN** documentation SHALL list required system dependencies (QEMU, binfmt_misc)
- **AND** documentation SHALL provide setup instructions per major Linux distribution
- **AND** documentation SHALL explain performance implications of emulated cross-compilation
- **AND** documentation SHALL list known package compatibility issues

#### Scenario: Package fails cross-compilation

- **WHEN** a package does not support cross-compilation
- **THEN** Nix SHALL fail with a meaningful error message
- **AND** documentation SHALL provide guidance on handling incompatible packages
- **AND** documentation SHALL suggest alternatives (native builder, package exclusion)
