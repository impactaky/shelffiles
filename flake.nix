{
  description = "Portable environment configuration";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.nix-ai-tools.url = "github:numtide/nix-ai-tools";

  outputs =
    { nixpkgs, nix-ai-tools, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Load user packages or use default packages if user packages don't exist
      loadPackages =
        _: pkgs: nix-ai-tools:
        let
          packagesPath = ./packages.nix;
        in
        import packagesPath pkgs nix-ai-tools;
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: {
        default = nixpkgs.legacyPackages.${system}.buildEnv {
          name = "shelffiles-env";
          paths = loadPackages system nixpkgs.legacyPackages.${system} (
            nix-ai-tools.packages.${system} or { }
          );
        };
      });
    };
}
