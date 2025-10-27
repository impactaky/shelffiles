# Deployment Capability Specification

## ADDED Requirements

### Requirement: Ansible Playbook Structure
The deployment system SHALL provide an Ansible playbook that automates the installation of nix-portable and shelffiles repository on remote hosts.

#### Scenario: Single host deployment via IP address
- **WHEN** user runs `ansible-playbook -i <ip_address>, playbook.yml`
- **THEN** the playbook targets the specified IP address
- **AND** installs nix-portable and shelffiles on that host

#### Scenario: Multi-host deployment via inventory file
- **WHEN** user creates an inventory file with multiple hosts
- **AND** runs `ansible-playbook -i inventory playbook.yml`
- **THEN** the playbook deploys to all hosts listed in the inventory

### Requirement: Minimal Target Dependencies
The deployment system SHALL operate with minimal dependencies on the target host, requiring only SSH access and basic POSIX commands.

#### Scenario: Deployment to busybox-based system
- **WHEN** target host has only busybox utilities (sh, mkdir, chmod, cp, tar)
- **AND** SSH server is running
- **THEN** the deployment completes successfully
- **AND** nix-portable and shelffiles are functional

#### Scenario: Target without HTTPS capability
- **WHEN** target host cannot make HTTPS connections
- **AND** does not have curl or wget installed
- **THEN** the deployment completes successfully by transferring binaries from control machine

### Requirement: Binary Acquisition via Ansible Tasks
The deployment system SHALL use Ansible tasks to download nix-portable binaries to the control machine and transfer them to targets, without requiring external shell scripts.

#### Scenario: Automatic binary download on first run
- **WHEN** nix-portable binaries do not exist in deployment/files/
- **THEN** Ansible get_url task downloads them from GitHub to control machine
- **AND** downloads both x86_64 and aarch64 versions
- **AND** uses creates: parameter for idempotency

#### Scenario: Using cached binaries
- **WHEN** nix-portable binaries already exist in deployment/files/
- **THEN** Ansible skips download step
- **AND** uses cached binaries for deployment
- **AND** supports offline/air-gapped deployment

### Requirement: Nix-portable Binary Transfer
The deployment system SHALL transfer the appropriate nix-portable binary from the control machine to the target host based on target architecture.

#### Scenario: x86_64 target deployment
- **WHEN** target host architecture is x86_64
- **THEN** the x86_64 nix-portable binary is copied from deployment/files/ using Ansible copy module
- **AND** executable permissions are set using Ansible file module
- **AND** binary is verified with command module executing `./nix-portable nix --version`

#### Scenario: aarch64 target deployment
- **WHEN** target host architecture is aarch64 (ARM64)
- **THEN** the aarch64 nix-portable binary is copied from deployment/files/ using Ansible copy module
- **AND** executable permissions are set using Ansible file module
- **AND** binary is verified with command module

#### Scenario: Existing nix-portable installation
- **WHEN** nix-portable is already installed on target
- **THEN** the installation step is skipped
- **AND** the playbook continues with repository deployment

### Requirement: Repository Synchronization
The deployment system SHALL synchronize the shelffiles repository from the control machine to the target host.

#### Scenario: Initial repository deployment
- **WHEN** shelffiles repository does not exist on target
- **THEN** the entire repository is copied to ~/shelffiles/ using Ansible synchronize module
- **AND** git-ignored files (cache/, result/, /nix, deployment/) are excluded
- **AND** setup.sh is executed with --no-root flag using Ansible command module

#### Scenario: Repository update
- **WHEN** shelffiles repository already exists on target
- **THEN** only changed files are synchronized using Ansible synchronize module
- **AND** local modifications in config/ are preserved
- **AND** build is re-run using command module if flake.nix or packages.nix changed

### Requirement: Authentication Methods
The deployment system SHALL support multiple authentication methods for connecting to target hosts.

#### Scenario: SSH key authentication
- **WHEN** user has SSH key configured for target host
- **THEN** the playbook connects without password prompt
- **AND** this is the recommended authentication method

#### Scenario: Interactive password authentication
- **WHEN** user runs playbook with `--ask-pass` flag
- **THEN** Ansible prompts for SSH password
- **AND** uses password for all target connections

#### Scenario: Ansible Vault encrypted password
- **WHEN** user stores password in ansible-vault encrypted file
- **AND** runs playbook with `--vault-password-file`
- **THEN** Ansible decrypts and uses password for connections
- **AND** password is never exposed in plain text

### Requirement: Pre-flight Validation
The deployment system SHALL validate target host compatibility before attempting installation.

#### Scenario: Successful pre-flight checks
- **WHEN** pre-flight validation runs
- **THEN** SSH connectivity is verified
- **AND** target architecture is detected (x86_64 or aarch64)
- **AND** required commands (sh, mkdir, chmod, cp, tar) are verified
- **AND** Python interpreter is found for Ansible modules

#### Scenario: Unsupported architecture detected
- **WHEN** target architecture is not x86_64 or aarch64
- **THEN** the playbook fails with clear error message
- **AND** lists supported architectures

#### Scenario: Missing required commands
- **WHEN** target lacks required POSIX commands
- **THEN** the playbook fails with error listing missing commands
- **AND** suggests installing busybox or coreutils

### Requirement: Idempotent Deployments
The deployment system SHALL support idempotent re-runs without breaking existing installations.

#### Scenario: Re-running deployment on configured host
- **WHEN** user re-runs the playbook on already-configured host
- **THEN** all tasks check current state before making changes
- **AND** no errors occur from duplicate installations
- **AND** only necessary updates are applied

### Requirement: Deployment Documentation
The deployment system SHALL provide comprehensive documentation for setup and usage.

#### Scenario: First-time user setup
- **WHEN** user reads deployment/README.md
- **THEN** instructions explain that binaries are downloaded automatically by Ansible
- **AND** provide example commands for single-host deployment
- **AND** document requirement to run from repository root
- **AND** document all authentication methods with security recommendations

#### Scenario: Troubleshooting connectivity issues
- **WHEN** user encounters deployment errors
- **THEN** documentation provides troubleshooting section
- **AND** includes common error messages with solutions
- **AND** explains how to verify SSH access manually

### Requirement: Offline Deployment Support
The deployment system SHALL support air-gapped deployments where target hosts have no internet connectivity.

#### Scenario: Deployment without target internet access
- **WHEN** target host cannot reach external networks
- **AND** control machine downloads binaries via Ansible get_url on first run
- **AND** binaries are cached in deployment/files/ directory
- **THEN** deployment completes successfully using only SSH connection
- **AND** no external network requests are made from target
- **AND** subsequent deployments use cached binaries
