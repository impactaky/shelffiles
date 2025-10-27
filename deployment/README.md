# Shelffiles Ansible Deployment

Automated deployment of shelffiles with nix-portable to a remote server using Ansible.

## Requirements

**Control Machine:**
- Ansible 2.9+
- Internet access (first run only)
- This repository cloned locally

**Target Machine:**
- SSH server
- Python 3
- Basic POSIX commands: sh, mkdir, chmod, cp, tar, rsync
- Supported architecture: x86_64 or aarch64

## Usage

Deploy to a host by IP address:

```bash
cd /path/to/shelffiles

# With SSH key
ansible-playbook -i "192.168.1.100," deployment/playbook.yml

# With password
ansible-playbook -i "192.168.1.100," deployment/playbook.yml --ask-pass

# Specify user
ansible-playbook -i "192.168.1.100," deployment/playbook.yml -u username --ask-pass
```

**Note**: The comma after the IP is required by Ansible.

## How It Works

1. **Binary Acquisition** (control machine):
   - Downloads nix-portable binaries from GitHub to `deployment/files/`
   - Cached for offline use after first run

2. **Pre-flight Checks** (target):
   - Validates architecture (x86_64 or aarch64)
   - Checks Python interpreter

3. **Nix-portable Installation** (target):
   - Transfers binary matching target architecture
   - Skipped if already installed

4. **Shelffiles Deployment** (target):
   - Synchronizes repository (excludes: .git/, cache/, result/, /nix, deployment/)
   - Runs `./setup.sh --no-root`
   - Creates XDG directories

5. **Verification**:
   - Tests nix command
   - Displays installation summary

## Configuration

Override defaults with `-e` flag:

```bash
# Custom installation directory
ansible-playbook -i "IP," deployment/playbook.yml -e "shelffiles_home=/opt/shelffiles"

# Force rebuild
ansible-playbook -i "IP," deployment/playbook.yml -e "shelffiles_force_rebuild=true"
```

Available variables:
- `shelffiles_home` (default: `~/shelffiles`)
- `shelffiles_force_rebuild` (default: `false`)
- `shelffiles_create_xdg_dirs` (default: `true`)
- `shelffiles_setup_args` (default: `""`)

## Offline Deployment

After first run, binaries are cached in `deployment/files/`. Subsequent deployments work offline.

To pre-cache binaries:
```bash
mkdir -p deployment/files
curl -L -o deployment/files/nix-portable-x86_64 \
  https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-x86_64
curl -L -o deployment/files/nix-portable-aarch64 \
  https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-aarch64
chmod +x deployment/files/nix-portable-*
```

## Verification

After deployment:
```bash
ssh user@192.168.1.100
cd ~/shelffiles
./nix-portable nix --version
./entrypoint/bash
```

## Troubleshooting

**Architecture error**: Target must be x86_64 or aarch64
```bash
ssh user@IP "uname -m"  # Check architecture
```

**Python not found**: Install python3 on target, or specify interpreter
```bash
ansible-playbook -i "IP," deployment/playbook.yml -e "ansible_python_interpreter=/usr/bin/python3"
```

**Verbose output**: Add `-v`, `-vv`, `-vvv`, or `-vvvv` flag

**Dry run**: Add `--check` flag (limited support for command tasks)

## File Structure

```
deployment/
├── playbook.yml           # Main playbook
├── README.md              # This file
├── files/                 # Binary cache (git-ignored)
└── roles/
    ├── nix-portable/      # Binary installation
    └── shelffiles/        # Repository deployment
```
