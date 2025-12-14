## 1. Revert automatic env generation

- [x] 1.1 Remove `shelffiles/generate_env.sh`
- [x] 1.2 Revert `flake.nix` to simple buildEnv without env generation
- [x] 1.3 Revert `entrypoint/env.sh` to not source generated environment file
- [x] 1.4 Revert `entrypoint/bash` to include HISTFILE setup directly
- [x] 1.5 Revert `entrypoint/zsh` to include ZDOTDIR setup directly
- [x] 1.6 Fix USER_ZDOTDIR to reference ZDOTDIR variable

## 2. Keep package environment files

- [x] 2.1 Keep `shelffiles/packages/*.sh` files for manual user sourcing
- [x] 2.2 Keep `.dockerignore` file

## 3. Update documentation

- [x] 3.1 Update `openspec/project.md` to remove references to `generated_env.sh`

## 4. Verify and test

- [x] 4.1 Build with `nix build` to ensure the simplified flake works (verified via Docker)
- [x] 4.2 Run test suite via `docker build -f test/Dockerfile .`

## 5. Commit and create PR

- [ ] 5.1 Commit the changes with descriptive message
- [ ] 5.2 Create PR with summary of breaking change
