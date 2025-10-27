# Ansible Deployment for Shelffiles with nix-portable

## Why

Shelffiles currently requires manual installation steps on target machines. To enable automated deployment to remote servers that may have limited connectivity (no HTTPS, no curl/wget), we need an Ansible-based deployment system that:
- Works with minimal dependencies (SSH + busybox commands only)
- Deploys nix-portable and shelffiles repository to target hosts
- Handles authentication securely
- Supports deployment to hosts specified by IP address

## What Changes

- Add Ansible playbook and roles for deploying shelffiles
- Support deployment via `-i <ip_address>` to specify target host
- Transfer nix-portable binary from control machine (avoiding HTTPS requirement on target)
- Clone/copy shelffiles repository to target machine
- Handle password authentication (interactive or via ansible-vault)
- Minimize dependency on target host tools (only SSH and busybox-level commands)
- Support both fresh installation and updates

## Impact

- Affected specs: New deployment capability (specs/deployment/spec.md)
- Affected code: New files under deployment/ directory
  - deployment/playbook.yml (main Ansible playbook)
  - deployment/roles/nix-portable/ (nix-portable installation role)
  - deployment/roles/shelffiles/ (shelffiles deployment role)
  - deployment/inventory_template (inventory file template)
  - deployment/README.md (deployment documentation)
- No breaking changes to existing functionality
