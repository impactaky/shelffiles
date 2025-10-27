# Implementation Tasks

## 1. Ansible Playbook Structure
- [ ] 1.1 Create deployment/ directory structure
- [ ] 1.2 Create main playbook.yml with host targeting via IP
- [ ] 1.3 Add pre-flight validation tasks (gather_facts, architecture check)
- [ ] 1.4 Create inventory template for dynamic host specification
- [ ] 1.5 Add ansible.cfg for SSH configuration

## 2. Binary Acquisition Tasks (runs on control machine)
- [ ] 2.1 Add task to create deployment/files/ directory on localhost
- [ ] 2.2 Add get_url task to download nix-portable-x86_64 from GitHub (delegate_to: localhost)
- [ ] 2.3 Add get_url task to download nix-portable-aarch64 from GitHub (delegate_to: localhost)
- [ ] 2.4 Configure idempotency using creates: parameter on get_url tasks
- [ ] 2.5 Add task to verify checksums (optional but recommended)

## 3. Nix-portable Installation Role
- [ ] 3.1 Create role structure (tasks/main.yml, defaults/main.yml, handlers/main.yml)
- [ ] 3.2 Add stat task to check if nix-portable already exists on target
- [ ] 3.3 Add copy task to transfer binary using ansible_architecture variable
- [ ] 3.4 Add file task to set executable permissions (mode: '0755')
- [ ] 3.5 Add command task to verify with './nix-portable nix --version'
- [ ] 3.6 Add conditional checks to skip installation if already present

## 4. Shelffiles Deployment Role
- [ ] 4.1 Create role structure (tasks/main.yml, defaults/main.yml)
- [ ] 4.2 Add synchronize task with exclusion patterns (.git/, cache/, result/, /nix, deployment/)
- [ ] 4.3 Add command task to run setup.sh with --no-root flag (chdir: ~/shelffiles)
- [ ] 4.4 Add stat task to check if result/ directory exists for idempotency
- [ ] 4.5 Add file tasks to ensure proper permissions on XDG directories
- [ ] 4.6 Add optional tasks for shell integration (conditional based on variables)

## 5. Post-deployment Verification Tasks
- [ ] 5.1 Add command task to test nix build on target
- [ ] 5.2 Add task to register installation paths as Ansible facts
- [ ] 5.3 Add debug task to display deployment summary
- [ ] 5.4 Add optional handler for build failures with clear error messages

## 6. Password and Authentication Handling
- [ ] 6.1 Document ansible_password variable usage in README
- [ ] 6.2 Document ansible-vault usage for password encryption
- [ ] 6.3 Add --ask-pass flag documentation for interactive password
- [ ] 6.4 Document SSH key authentication as preferred method
- [ ] 6.5 Add example inventory files for each authentication method

## 7. Documentation
- [ ] 7.1 Create deployment/README.md with usage examples
- [ ] 7.2 Document minimal target requirements (SSH server, busybox, Python)
- [ ] 7.3 Document playbook execution from repository root requirement
- [ ] 7.4 Add troubleshooting section with common Ansible errors
- [ ] 7.5 Document offline deployment workflow (pre-cached binaries)
- [ ] 7.6 Add architecture diagram showing control machine and target flow

## 8. Testing
- [ ] 8.1 Test deployment to fresh Ubuntu/Debian system
- [ ] 8.2 Test deployment to minimal busybox-based system
- [ ] 8.3 Test deployment without HTTPS on target (verify no external connections)
- [ ] 8.4 Test idempotent re-deployment (verify no unnecessary changes)
- [ ] 8.5 Verify both x86_64 and aarch64 architectures
- [ ] 8.6 Test with all authentication methods (SSH key, vault, --ask-pass)
- [ ] 8.7 Test binary download caching (run twice, verify get_url uses cached file)
