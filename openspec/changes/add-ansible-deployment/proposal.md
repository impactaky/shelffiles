# Ansible Deployment for Shelffiles with nix-portable

## Why

Shelffiles currently requires manual installation steps on target machines. To enable automated deployment to remote servers that may have limited connectivity (no HTTPS, no curl/wget), we need an Ansible-based deployment system that:
- Works with minimal dependencies (SSH + busybox commands only)
- Deploys nix-portable and shelffiles repository to target hosts
- Handles authentication securely
- Supports deployment to hosts specified by IP address

## What Changes

- Add Ansible playbook and roles for deploying shelffiles (pure Ansible, no shell scripts)
- Support deployment via `-i <ip_address>,` to specify target host
- Use Ansible get_url tasks to download nix-portable binaries to control machine
- Transfer nix-portable binary from control machine (avoiding HTTPS requirement on target)
- Use Ansible synchronize module to copy shelffiles repository to target machine
- Use Ansible command module to execute setup.sh and verification tasks
- Handle password authentication (interactive or via ansible-vault)
- Minimize dependency on target host tools (only SSH and busybox-level commands)
- Support both fresh installation and updates with idempotency

## Impact

- Affected specs: New deployment capability (specs/deployment/spec.md)
- Affected code: New files under deployment/ directory
  - deployment/playbook.yml (main Ansible playbook with all tasks)
  - deployment/roles/nix-portable/ (nix-portable installation role)
  - deployment/roles/shelffiles/ (shelffiles deployment role)
  - deployment/ansible.cfg (Ansible configuration)
  - deployment/README.md (deployment documentation with inventory examples)
  - deployment/files/ (directory for cached nix-portable binaries, git-ignored)
- No breaking changes to existing functionality
- No shell scripts added - all logic in Ansible tasks
