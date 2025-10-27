# Design Document: Ansible Deployment for Shelffiles

## Context

Shelffiles requires Nix (or nix-portable) to be installed on target systems. Many deployment scenarios involve:
- Remote servers without internet access or restricted HTTPS connectivity
- Minimal operating systems (busybox-based) without curl/wget
- Need for automated, repeatable deployments
- Multi-host deployments with different architectures

## Goals / Non-Goals

**Goals:**
- Enable automated deployment using Ansible
- Work with minimal target dependencies (SSH + basic POSIX commands)
- Support offline/air-gapped environments (no HTTPS on target)
- Handle nix-portable and shelffiles repository deployment
- Support both initial installation and updates
- Allow IP-based targeting: `ansible-playbook -i <ip>, playbook.yml`

**Non-Goals:**
- Full configuration management (Ansible will only deploy, not manage configs)
- Multi-distro package management (focuses on nix-portable approach)
- Building packages on control machine (build happens on target)
- Container orchestration or clustering

## Decisions

### 1. Transfer Method: Copy Module vs Synchronize
**Decision:** Use Ansible `copy` module for nix-portable binary, `synchronize` for repository

**Rationale:**
- `copy` module works with just SSH, no rsync needed on target
- nix-portable is single binary, simple to copy
- `synchronize` (rsync) more efficient for repository but acceptable to require rsync
- Fallback: git archive + unarchive modules if rsync unavailable

**Alternatives considered:**
- Using `fetch` from GitHub on target → requires HTTPS connectivity (rejected)
- Base64 encoding binary in playbook → inefficient, error-prone (rejected)

### 2. Nix-portable Binary Source
**Decision:** Pre-download nix-portable to control machine, transfer to target

**Rationale:**
- Target may not have HTTPS or any HTTP client
- Control machine likely has internet access
- Allows verification of binary before deployment
- Supports air-gapped deployments

**Implementation:**
- Store binaries in `deployment/files/nix-portable-{x86_64,aarch64}`
- Provide download script: `deployment/scripts/download-nix-portable.sh`
- Use `copy` module with `src: deployment/files/nix-portable-{{ target_arch }}`

### 3. Password Authentication Strategy
**Decision:** Support multiple methods with documentation preference order

**Methods (in order of preference):**
1. SSH key authentication (most secure, recommended)
2. Ansible Vault encrypted password file
3. `--ask-pass` flag (interactive, less secure)
4. Plain `ansible_password` variable (discouraged, documented for testing only)

**Rationale:**
- SSH keys are standard DevOps practice
- Vault provides secure credential storage when keys unavailable
- Interactive password for quick testing
- Plain password never committed to version control

### 4. Repository Transfer Method
**Decision:** Use `synchronize` module with `--exclude` patterns for git-ignored files

**Rationale:**
- Efficient for large repository and updates
- Preserves permissions and timestamps
- Built-in exclude support for `.git/`, `cache/`, `result/`, etc.
- Idempotent by default

**Fallback plan:**
- If rsync unavailable: use `copy` with `src: ./ dest: ~/shelffiles/`
- Document rsync as soft dependency

### 5. Inventory Management
**Decision:** Provide template inventory file, support ad-hoc `-i <ip>,` usage

**Rationale:**
- Single-host deployment: `ansible-playbook -i 192.168.1.100, playbook.yml`
- Multi-host: create inventory file from template
- Comma after IP required for ad-hoc (Ansible convention)

**Template includes:**
```ini
[shelffiles_targets]
target1 ansible_host=192.168.1.100 ansible_user=myuser

[shelffiles_targets:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 6. Target System Requirements Validation
**Decision:** Add pre-task validation for minimal dependencies

**Checks:**
- SSH connectivity
- POSIX shell (sh/bash/zsh)
- Basic commands: mkdir, chmod, cp, tar
- Python interpreter (for Ansible modules)
- Architecture detection: `uname -m`

**Rationale:**
- Fail fast with clear error messages
- Document exact requirements upfront
- Avoid partial deployments

## Architecture

```
Control Machine                           Target Machine
┌─────────────────┐                      ┌──────────────────┐
│ shelffiles/     │                      │                  │
│ ├─ deployment/  │                      │ ~/shelffiles/    │
│    ├─ files/    │                      │ ├─ setup.sh      │
│    │  ├─ nix-portable-x86_64  ────────►│ ├─ nix-portable  │
│    │  └─ nix-portable-aarch64          │ ├─ flake.nix     │
│    ├─ playbook.yml              ───┐   │ └─ ...           │
│    ├─ roles/                       │   │                  │
│    │  ├─ nix-portable/ ────────────┤   │ ~/              │
│    │  └─ shelffiles/   ────────────┘   │ └─ .bashrc (opt) │
│    └─ README.md                        │                  │
└─────────────────┘                      └──────────────────┘
```

### Playbook Flow

```
1. Pre-flight Checks
   ├─ Validate SSH connectivity
   ├─ Check target architecture
   └─ Verify minimal commands available

2. Nix-portable Deployment (role: nix-portable)
   ├─ Check existing installation
   ├─ Copy binary for target architecture
   ├─ Set executable permissions
   └─ Verify with `./nix-portable nix --version`

3. Shelffiles Deployment (role: shelffiles)
   ├─ Synchronize repository files
   ├─ Run setup.sh --no-root
   ├─ Configure XDG directories
   └─ Optional: Add shell integration

4. Post-deployment Verification
   ├─ Test nix build
   └─ Report installation paths
```

## Risks / Trade-offs

### Risk: Large binary transfer over slow connections
**Mitigation:**
- nix-portable is ~60MB compressed
- Document expected transfer time based on connection speed
- Support resumable transfer via rsync for repository
- Consider splitting into separate nix-portable and shelffiles playbooks

### Risk: Architecture mismatch
**Mitigation:**
- Automatic architecture detection: `ansible_architecture` fact
- Validation task fails early if unsupported architecture
- Clear error message with supported architectures list

### Risk: Insufficient permissions on target
**Mitigation:**
- Use `--no-root` flag for nix-portable (no sudo needed)
- Document that user needs write access to home directory only
- Validate permissions in pre-flight checks

### Risk: Ansible version compatibility
**Mitigation:**
- Document minimum Ansible version (2.9+)
- Use only core modules (copy, synchronize, shell, file)
- Test with Ansible 2.9, 2.10, and latest

### Trade-off: Repository transfer size vs freshness
**Decision:** Transfer full working copy
**Rationale:**
- Ensures consistency with control machine
- Allows offline builds
- Alternative (git clone on target) requires git and connectivity

## Migration Plan

### Fresh Installation
1. Prepare control machine:
   ```bash
   cd deployment
   ./scripts/download-nix-portable.sh
   ```

2. Deploy to target:
   ```bash
   ansible-playbook -i <target_ip>, playbook.yml --ask-pass
   ```

3. SSH to target and verify:
   ```bash
   ssh user@<target_ip>
   cd ~/shelffiles
   ./nix-portable nix build --extra-experimental-features nix-command --extra-experimental-features flakes
   ```

### Update Existing Installation
- Same playbook with idempotency checks
- Detects existing nix-portable (skips installation)
- Synchronizes repository changes only
- Re-runs build if flake.nix or packages.nix changed

### Rollback
- Manual: SSH to target and restore from backup
- Automated: Add optional backup task in playbook (creates `~/shelffiles.backup.TIMESTAMP/`)

## Open Questions

1. **Should we support direct nix installation (non-portable)?**
   - Current decision: No, focus on nix-portable for consistency
   - Rationale: Avoids sudo requirements, works everywhere
   - Revisit if enterprise users require system-wide nix

2. **Should we integrate with systemd for persistent environments?**
   - Current decision: Out of scope, users can add manually
   - Could add optional role in future for systemd user services

3. **Should we support configuration file deployment (config/)?**
   - Current decision: No, users manage config/ separately
   - Rationale: Config is personal, shouldn't be overwritten
   - Could add `config_template/` with safe merge in future

4. **Should we bundle specific nix-portable versions or always download latest?**
   - Current decision: Script downloads latest from GitHub
   - Alternative: Pin to specific tested version in deployment/files/
   - Recommendation: Pin version, document update process
