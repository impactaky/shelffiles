## REMOVED Requirements

### Requirement: Automatic Package Environment Generation

**Reason**: Conflicts with other environment management tools (e.g., mise) and makes package configuration opaque. Users should explicitly configure package-specific environment variables.

**Migration**: Users who need package-specific environment variables (e.g., HISTFILE, ZDOTDIR, NPM_CONFIG_USERCONFIG) should add them to `user_env.sh` in the repository root.

#### Scenario: No automatic env generation on build

- **WHEN** user runs `nix build`
- **THEN** the build SHALL NOT generate `generated_env.sh`
- **AND** the build output SHALL NOT include `shelffiles-env-generator` derivation
