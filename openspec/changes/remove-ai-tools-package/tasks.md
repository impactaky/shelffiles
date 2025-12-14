## 1. Implementation

- [ ] 1.1 Remove `nix-ai-tools` input from `flake.nix`
- [ ] 1.2 Simplify `loadPackages` function to remove `nix-ai-tools` parameter
- [ ] 1.3 Update `packages.nix` to single-parameter function signature
- [ ] 1.4 Update `test/packages.nix` to single-parameter function signature
- [ ] 1.5 Update `openspec/project.md` to remove nix-ai-tools references

## 2. Validation

- [ ] 2.1 Run `nix flake check` to verify flake syntax
- [ ] 2.2 Run Docker-based test suite to ensure shell integration still works
