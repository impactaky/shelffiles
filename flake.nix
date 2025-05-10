{
  description = "Portable environment configuration";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = { self, nixpkgs, }:
    let
      systems =
        [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];

      # Load user packages or use default packages if user packages don't exist
      loadPackages = system: pkgs:
        let
          packagesPath = ./packages.nix;
        in import packagesPath pkgs;
    in {
      packages = nixpkgs.lib.genAttrs systems (system: {
        default = nixpkgs.legacyPackages.${system}.buildEnv {
          name = "shelffiles-env";
          paths = loadPackages system nixpkgs.legacyPackages.${system};
        };
      });
    };
}
