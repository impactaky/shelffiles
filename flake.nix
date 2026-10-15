{
  description = "Portable environment configuration";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Load user packages from root packages.nix
      loadPackages = _: pkgs: import ./packages.nix pkgs;
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: {
        default = nixpkgs.legacyPackages.${system}.buildEnv {
          name = "shelffiles-env";
          # cacert is always included: entrypoint/env.sh points TLS clients at
          # its bundle so the environment does not depend on host certificates.
          paths = [
            nixpkgs.legacyPackages.${system}.cacert
          ]
          ++ loadPackages system nixpkgs.legacyPackages.${system};
        };
      });
    };
}
