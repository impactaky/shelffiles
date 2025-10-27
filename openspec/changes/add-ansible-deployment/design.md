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

### 2. Nix-portable Binary Acquisition
**Decision:** Use Ansible tasks to download nix-portable from GitHub to control machine, then transfer to target

**Rationale:**
- Target may not have HTTPS or any HTTP client
- Control machine likely has internet access
- Allows verification of binary before deployment
- Supports air-gapped deployments (binaries cached on control machine)
- Pure Ansible approach - no shell scripts needed

**Implementation:**
- Use `get_url` task to download from GitHub releases to `deployment/files/` on control machine
  - Runs on `localhost` (control machine) with `delegate_to: localhost`
  - Downloads `nix-portable-x86_64` and `nix-portable-aarch64`
  - Uses `creates:` parameter for idempotency (skip if already exists)
- Use `copy` module to transfer appropriate binary to target
  - `src: deployment/files/nix-portable-{{ ansible_architecture }}`
  - `dest: ~/shelffiles/nix-portable`
  - `mode: '0755'`
- URL format: `https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-{{ arch }}`

### 3. Repository Transfer to Control Machine
**Decision:** Use Ansible tasks to prepare repository on control machine before transferring to target

**Rationale:**
- Avoid assumptions about where playbook is run from
- Allow running playbook from any directory
- Support packaging deployment as standalone directory
- Pure Ansible approach

**Implementation:**
- Option A: Playbook assumes it's run from repository root (simpler)
  - Use `synchronize` with `src: "{{ playbook_dir }}/.." dest: ~/shelffiles/`
  - Excludes: `.git/`, `cache/`, `result/`, `/nix`, `deployment/`
- Option B: Clone repository on control machine first (more flexible)
  - Use `git` module with `delegate_to: localhost` to clone/update local copy
  - Then synchronize from local copy to target
  - Allows deployment directory to be independent

**Chosen:** Option A for simplicity, document requirement to run from repo root

### 4. Password Authentication Strategy
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

### 5. Setup Execution Method
**Decision:** Use Ansible `command` module to execute setup.sh, not shell scripts

**Rationale:**
- All deployment logic in Ansible tasks
- No separate shell scripts to maintain
- Better error handling and logging through Ansible
- Idempotency controlled by Ansible facts

**Implementation:**
- Use `stat` module to check if nix-portable already installed
- Use `command` module: `cmd: ./setup.sh --no-root`
  - `chdir: ~/shelffiles`
  - `creates: ~/shelffiles/result` for idempotency
- Use `command` module for verification: `./nix-portable nix --version`

### 6. Inventory Management
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

### 7. Target System Requirements Validation
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
1. Pre-flight Checks (Ansible tasks on localhost and target)
   ├─ Gather facts from target (ansible_architecture, etc.)
   ├─ Validate target architecture (x86_64 or aarch64)
   ├─ Check Python interpreter exists
   └─ Verify SSH connectivity

2. Binary Acquisition (Ansible tasks on localhost)
   ├─ Create deployment/files/ directory on control machine
   ├─ Download nix-portable binaries via get_url module (delegate_to: localhost)
   │  ├─ https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-x86_64
   │  └─ https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-aarch64
   └─ Use creates: parameter for idempotency

3. Nix-portable Deployment (Ansible tasks on target)
   ├─ Check if nix-portable already exists (stat module)
   ├─ Copy appropriate binary via copy module
   │  └─ src: deployment/files/nix-portable-{{ ansible_architecture }}
   ├─ Set executable permissions via file module
   └─ Verify installation via command module

4. Shelffiles Deployment (Ansible tasks on target)
   ├─ Synchronize repository via synchronize module
   │  └─ Excludes: .git/, cache/, result/, /nix, deployment/
   ├─ Execute setup.sh via command module
   │  └─ cmd: ./setup.sh --no-root, chdir: ~/shelffiles
   └─ Verify build via command module

5. Post-deployment Verification (Ansible tasks on target)
   ├─ Test nix build via command module
   ├─ Register installation paths
   └─ Display summary via debug module
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
1. Run playbook (binaries downloaded automatically by Ansible):
   ```bash
   cd /path/to/shelffiles
   ansible-playbook -i <target_ip>, deployment/playbook.yml --ask-pass
   ```

   The playbook will:
   - Download nix-portable binaries to `deployment/files/` on first run
   - Transfer appropriate binary to target
   - Synchronize shelffiles repository
   - Execute setup.sh on target

2. SSH to target and verify (optional - playbook does this):
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
