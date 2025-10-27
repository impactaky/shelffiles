# Shelffiles Ansible Deployment

Automated deployment of shelffiles with nix-portable to remote servers using Ansible.

## Features

- **Minimal target dependencies**: Only requires SSH, Python, and basic POSIX commands (mkdir, chmod, cp, tar)
- **No HTTPS on target**: Binaries downloaded to control machine, then transferred via SSH
- **Pure Ansible**: No shell scripts - all logic in Ansible tasks
- **Idempotent**: Safe to re-run, only applies necessary changes
- **Multi-architecture**: Supports x86_64 and aarch64 (ARM64)
- **Offline-friendly**: Binaries cached on control machine after first download

## Requirements

### Control Machine (where you run Ansible)
- Ansible 2.9 or later
- Internet access (first run only, to download nix-portable binaries)
- This repository cloned locally

### Target Machine (where shelffiles will be deployed)
- SSH server running
- Python 3 (for Ansible modules)
- Basic POSIX commands: sh, mkdir, chmod, cp, tar
- Write access to home directory (no sudo required)
- Supported architecture: x86_64 or aarch64

## Quick Start

### 1. Single Host Deployment

Deploy to a single host by IP address:

```bash
# Navigate to repository root
cd /path/to/shelffiles

# Deploy with interactive password prompt
ansible-playbook -i "192.168.1.100," deployment/playbook.yml --ask-pass

# Or with SSH key (no password prompt)
ansible-playbook -i "192.168.1.100," deployment/playbook.yml
```

**Note**: The comma after the IP address is required for Ansible ad-hoc inventory.

### 2. Multi-Host Deployment

Create an inventory file:

```bash
# Copy the example inventory
cp deployment/inventory.example deployment/inventory

# Edit with your hosts
vim deployment/inventory
```

Deploy to all hosts:

```bash
cd /path/to/shelffiles
ansible-playbook deployment/playbook.yml
```

## Authentication Methods

### SSH Key Authentication (Recommended)

Most secure and convenient. Set up SSH key on target:

```bash
ssh-copy-id user@target-host
ansible-playbook -i "target-host," deployment/playbook.yml
```

### Interactive Password

Prompt for password at runtime:

```bash
ansible-playbook -i "target-host," deployment/playbook.yml --ask-pass
```

Requires `sshpass` to be installed on control machine:
```bash
# Ubuntu/Debian
sudo apt install sshpass

# macOS
brew install hudochenkov/sshpass/sshpass
```

### Ansible Vault (Encrypted Password)

Store password securely:

```bash
# Create encrypted vault file
ansible-vault create deployment/vault.yml

# Add password in editor:
# ansible_password: your_password_here

# Deploy with vault
ansible-playbook -i deployment/inventory deployment/playbook.yml --ask-vault-pass
```

Reference in inventory:
```ini
[shelffiles_targets]
myserver ansible_host=192.168.1.100 ansible_user=deploy ansible_password="{{ vault_password }}"
```

## Deployment Process

The playbook performs these steps automatically:

```
1. Pre-flight Checks
   ├─ Gather facts from target (architecture, OS)
   ├─ Validate architecture (x86_64 or aarch64)
   └─ Check Python interpreter

2. Binary Acquisition (on control machine)
   ├─ Create deployment/files/ directory
   ├─ Download nix-portable-x86_64 from GitHub
   ├─ Download nix-portable-aarch64 from GitHub
   └─ Cache binaries for future deployments

3. Nix-portable Installation (on target)
   ├─ Check if already installed
   ├─ Transfer appropriate binary (based on architecture)
   ├─ Set executable permissions
   └─ Verify installation

4. Shelffiles Deployment (on target)
   ├─ Synchronize repository from control machine
   ├─ Exclude: .git/, cache/, result/, /nix, deployment/
   ├─ Run setup.sh --no-root
   └─ Verify build succeeded

5. Post-Deployment
   ├─ Test nix command
   ├─ Create XDG directories (cache/, share/, state/)
   └─ Display summary
```

## Configuration Options

### Playbook Variables

Set in inventory file under `[shelffiles_targets:vars]` or via `-e` flag:

| Variable | Default | Description |
|----------|---------|-------------|
| `shelffiles_home` | `~/shelffiles` | Installation directory on target |
| `shelffiles_force_rebuild` | `false` | Force rebuild even if already built |
| `shelffiles_create_xdg_dirs` | `true` | Create XDG directories (cache/, share/, state/) |
| `shelffiles_setup_args` | `""` | Additional arguments for setup.sh |

### Example: Custom Installation Directory

```bash
ansible-playbook -i inventory deployment/playbook.yml \
  -e "shelffiles_home=/opt/shelffiles"
```

### Example: Force Rebuild

```bash
ansible-playbook -i inventory deployment/playbook.yml \
  -e "shelffiles_force_rebuild=true"
```

## Offline/Air-Gapped Deployment

For targets without internet access:

1. **First deployment** (control machine has internet):
   ```bash
   ansible-playbook -i "target," deployment/playbook.yml
   ```
   Binaries are downloaded to `deployment/files/` on control machine.

2. **Subsequent deployments** (no internet needed):
   - Binaries are already cached in `deployment/files/`
   - Ansible skips download step
   - Works completely offline

3. **Pre-download binaries** (optional):
   ```bash
   # Manually download to cache before first deployment
   cd deployment
   curl -L -o files/nix-portable-x86_64 \
     https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-x86_64
   curl -L -o files/nix-portable-aarch64 \
     https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-aarch64
   chmod +x files/nix-portable-*
   ```

## Verification

After deployment, SSH to target and verify:

```bash
ssh user@target-host
cd ~/shelffiles

# Check nix-portable version
./nix-portable nix --version

# Enter bash environment
./entrypoint/bash

# List available packages
nix search nixpkgs hello
```

## Troubleshooting

### Error: "Unsupported architecture"

**Cause**: Target architecture is not x86_64 or aarch64

**Solution**: Check architecture on target:
```bash
ssh user@target "uname -m"
```

Only x86_64 and aarch64 are supported. For other architectures, nix-portable must be built manually.

### Error: "Permission denied" during SSH

**Cause**: SSH authentication failed

**Solutions**:
- Verify SSH access: `ssh user@target`
- Use `--ask-pass` flag for password authentication
- Set up SSH key: `ssh-copy-id user@target`
- Check `ansible_user` in inventory matches SSH user

### Error: "Python interpreter not found"

**Cause**: Python 3 not available on target

**Solution**: Install Python on target:
```bash
# Debian/Ubuntu
sudo apt install python3

# RHEL/CentOS
sudo yum install python3

# Specify custom interpreter in inventory
ansible_python_interpreter=/usr/local/bin/python3
```

### Error: "rsync not found"

**Cause**: `synchronize` module requires rsync on target

**Solution**: Install rsync on target:
```bash
# Debian/Ubuntu
sudo apt install rsync

# RHEL/CentOS/Rocky
sudo yum install rsync

# Alpine
apk add rsync
```

### Error: "setup.sh failed"

**Cause**: Build error during nix setup

**Solution**: Check setup.sh output in Ansible log. Common causes:
- Insufficient disk space (needs ~2GB for Nix store)
- Missing system dependencies (should be minimal with nix-portable)
- Corrupted download (re-run with `-e "shelffiles_force_rebuild=true"`)

### Verbose Output

Run with increased verbosity to debug:

```bash
# Level 1: Show task results
ansible-playbook -v -i inventory deployment/playbook.yml

# Level 2: Show task input
ansible-playbook -vv -i inventory deployment/playbook.yml

# Level 3: Show task execution details
ansible-playbook -vvv -i inventory deployment/playbook.yml

# Level 4: Show connection debugging
ansible-playbook -vvvv -i inventory deployment/playbook.yml
```

### Dry Run

Test without making changes:

```bash
ansible-playbook -i inventory deployment/playbook.yml --check
```

Note: `--check` mode has limitations with command/shell modules.

## Architecture Diagram

```
Control Machine                           Target Machine
┌─────────────────────────┐              ┌──────────────────────┐
│                         │              │                      │
│ shelffiles/             │              │ ~/shelffiles/        │
│ ├─ deployment/          │              │ ├─ nix-portable      │
│ │  ├─ playbook.yml ─────┼─────────────►│ ├─ setup.sh          │
│ │  ├─ roles/            │  Ansible     │ ├─ flake.nix         │
│ │  │  ├─ nix-portable/  │    SSH       │ ├─ packages.nix      │
│ │  │  └─ shelffiles/    │              │ ├─ entrypoint/       │
│ │  └─ files/            │              │ ├─ result -> /nix/.. │
│ │     ├─ nix-portable-  │  Transfer    │ ├─ cache/            │
│ │     │  x86_64   ──────┼─────────────►│ ├─ share/            │
│ │     └─ nix-portable-  │              │ └─ state/            │
│ │        aarch64        │              │                      │
│ └─ ...                  │              └──────────────────────┘
│                         │
│ Internet                │
│ ├─ GitHub (first run) ──┤
│ └─ nix-portable releases│
└─────────────────────────┘
```

## Advanced Usage

### Limit Execution to Specific Hosts

```bash
# Deploy only to hosts matching pattern
ansible-playbook -i inventory deployment/playbook.yml --limit "server1,server2"

# Deploy only to x86_64 hosts
ansible-playbook -i inventory deployment/playbook.yml --limit "x86_64_hosts"
```

### Run Specific Roles

```bash
# Only install nix-portable (skip shelffiles)
ansible-playbook -i inventory deployment/playbook.yml --tags "nix-portable"

# Only deploy shelffiles (skip nix-portable check)
ansible-playbook -i inventory deployment/playbook.yml --tags "shelffiles"
```

Note: Tags must be added to playbook.yml roles first.

### Override Repository Source

To deploy from a different repository or branch:

```bash
# Not directly supported - synchronize uses local files
# Workaround: git clone specific branch locally, then deploy
git clone -b feature-branch https://github.com/user/shelffiles.git /tmp/shelffiles
cd /tmp/shelffiles
ansible-playbook -i "target," deployment/playbook.yml
```

## File Structure

```
deployment/
├── playbook.yml              # Main playbook
├── ansible.cfg               # Ansible configuration
├── inventory.example         # Inventory template
├── README.md                 # This file
├── files/                    # Binary cache (git-ignored)
│   ├── nix-portable-x86_64   # Downloaded on first run
│   └── nix-portable-aarch64  # Downloaded on first run
└── roles/
    ├── nix-portable/
    │   ├── tasks/main.yml    # Installation tasks
    │   ├── defaults/main.yml # Default variables
    │   └── handlers/main.yml # Event handlers
    └── shelffiles/
        ├── tasks/main.yml    # Deployment tasks
        └── defaults/main.yml # Default variables
```

## Security Considerations

1. **SSH Key Authentication**: Strongly recommended over passwords
2. **Host Key Checking**: Disabled in ansible.cfg for testing - enable in production
3. **Vault Passwords**: Use `ansible-vault` for sensitive data, never commit plain passwords
4. **No Sudo Required**: Deployment uses `--no-root` flag, no privilege escalation
5. **Minimal Attack Surface**: Only SSH and Python required on target

## CI/CD Integration

### GitLab CI Example

```yaml
deploy-shelffiles:
  stage: deploy
  script:
    - ansible-playbook -i "$INVENTORY" deployment/playbook.yml
  variables:
    ANSIBLE_HOST_KEY_CHECKING: "False"
  only:
    - main
```

### GitHub Actions Example

```yaml
- name: Deploy Shelffiles
  env:
    ANSIBLE_HOST_KEY_CHECKING: "False"
  run: |
    ansible-playbook -i inventory deployment/playbook.yml
```

## Support

For issues specific to deployment:
- Check [Troubleshooting](#troubleshooting) section
- Run with `-vvv` for detailed output
- Review Ansible logs

For shelffiles issues:
- See main repository [README](../README.md)
- Check [example configurations](../example/)

## License

Same as shelffiles main repository.
