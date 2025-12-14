## 1. Revert commit 1fbf15d

- [ ] 1.1 Run `git revert 1fbf15d067fb5bc899528c996ea9a53f5a886b9f --no-commit` to stage the revert
- [ ] 1.2 Review the reverted changes to ensure they match expected removal

## 2. Update documentation

- [ ] 2.1 Update `openspec/project.md` to remove references to `generated_env.sh` and package-specific environment generation
- [ ] 2.2 Update `CLAUDE.md` if it references the removed feature

## 3. Verify and test

- [ ] 3.1 Build with `nix build` to ensure the simplified flake works
- [ ] 3.2 Run test suite via `docker build -f test/Dockerfile .`
- [ ] 3.3 Manually verify shell entrypoints work correctly

## 4. Commit and create PR

- [ ] 4.1 Commit the changes with descriptive message
- [ ] 4.2 Create PR with summary of breaking change
