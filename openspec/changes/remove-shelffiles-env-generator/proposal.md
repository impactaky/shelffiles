## Why

The automatic environment generation feature (`shelffiles-env-generator`) creates conflicts when users use other package/environment management tools like mise. The automatic detection and generation of package-specific environment variables makes it difficult to correctly manage packages across multiple tools. Removing this feature simplifies the codebase and gives users explicit control over their environment setup.

## What Changes

- **BREAKING**: Remove automatic `generated_env.sh` generation from nix build process
- Remove `shelffiles/generate_env.sh` script
- Remove `shelffiles/packages/*.sh` environment configuration files
- Remove `shelffiles/packages/.shellcheckrc`
- Revert `flake.nix` to simpler `buildEnv` without env generation
- Revert `entrypoint/env.sh` to not source generated environment file
- Revert `entrypoint/bash` to include HISTFILE setup directly
- Revert `entrypoint/zsh` to include ZDOTDIR setup directly
- Revert `test/Dockerfile` COPY command
- Remove `.dockerignore` file

## Impact

- Affected specs: nix-build (or shell-integration if exists)
- Affected code: `flake.nix`, `entrypoint/env.sh`, `entrypoint/bash`, `entrypoint/zsh`, `shelffiles/`, `test/Dockerfile`, `.dockerignore`
- Users who relied on automatic environment setup will need to add package-specific environment variables to `user_env.sh` manually
