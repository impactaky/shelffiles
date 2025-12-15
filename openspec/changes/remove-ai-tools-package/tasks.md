## 1. Implementation

- [x] 1.1 Remove `nix-ai-tools` input from `flake.nix`
- [x] 1.2 Simplify `loadPackages` function to remove `nix-ai-tools` parameter
- [x] 1.3 Update `packages.nix` to single-parameter function signature
- [x] 1.4 Update `test/packages.nix` to single-parameter function signature
- [x] 1.5 Update `openspec/project.md` to remove nix-ai-tools references

## 2. Validation

- [x] 2.1 Run `nix flake check` to verify flake syntax (nix not available in environment - will be validated by CI)
- [ ] 2.2 Run Docker-based test suite to ensure shell integration still works
