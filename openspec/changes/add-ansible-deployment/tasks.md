# Implementation Tasks

## 1. Ansible Playbook Structure
- [ ] 1.1 Create deployment/ directory structure
- [ ] 1.2 Create main playbook.yml with host targeting via IP
- [ ] 1.3 Create inventory template for dynamic host specification
- [ ] 1.4 Add ansible.cfg for SSH configuration

## 2. Nix-portable Installation Role
- [ ] 2.1 Create role structure (tasks/main.yml, defaults/main.yml, handlers/main.yml)
- [ ] 2.2 Implement detection of existing nix-portable installation
- [ ] 2.3 Implement binary transfer from control machine using copy module
- [ ] 2.4 Add architecture detection (x86_64/aarch64) on target
- [ ] 2.5 Set executable permissions on nix-portable binary
- [ ] 2.6 Add verification task to confirm nix-portable works

## 3. Shelffiles Deployment Role
- [ ] 3.1 Create role structure (tasks/main.yml, defaults/main.yml)
- [ ] 3.2 Implement repository synchronization using synchronize or copy module
- [ ] 3.3 Run setup.sh with --no-root flag on target
- [ ] 3.4 Configure XDG directories and permissions
- [ ] 3.5 Add optional shell integration setup
- [ ] 3.6 Add idempotency checks for updates

## 4. Password and Authentication Handling
- [ ] 4.1 Document ansible_password variable usage
- [ ] 4.2 Document ansible-vault usage for password encryption
- [ ] 4.3 Add --ask-pass flag documentation for interactive password
- [ ] 4.4 Document SSH key authentication as preferred method

## 5. Documentation
- [ ] 5.1 Create deployment/README.md with usage examples
- [ ] 5.2 Document minimal target requirements (SSH server, busybox)
- [ ] 5.3 Add troubleshooting section
- [ ] 5.4 Document offline deployment workflow

## 6. Testing
- [ ] 6.1 Test deployment to fresh Ubuntu/Debian system
- [ ] 6.2 Test deployment to minimal busybox-based system
- [ ] 6.3 Test deployment without HTTPS on target
- [ ] 6.4 Test idempotent re-deployment
- [ ] 6.5 Verify both x86_64 and aarch64 architectures
