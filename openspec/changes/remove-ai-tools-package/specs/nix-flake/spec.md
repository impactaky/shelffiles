## REMOVED Requirements

### Requirement: nix-ai-tools Integration

**Reason**: Alternative tools like mise handle AI tooling installation more flexibly with simpler configuration. Maintaining a dedicated flake input adds complexity for minimal benefit.

**Migration**: Users should use mise, direct nixpkgs packages, or other package managers for AI development tools.

#### Scenario: User previously using nix-ai-tools

- **WHEN** user has nix-ai-tools packages in their packages.nix
- **THEN** they must migrate to alternative installation methods (mise, nixpkgs, etc.)
