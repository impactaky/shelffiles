{
  description = "Portable environment configuration";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
  inputs.nixpkgs-darwin.url = "github:nixos/nixpkgs?ref=nixpkgs-26.05-darwin";
  inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }@inputs:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      pkgsFor =
        system:
        (if nixpkgs.lib.hasSuffix "-darwin" system then inputs.nixpkgs-darwin else nixpkgs)
        .legacyPackages.${system};

      # Load user packages from root packages.nix
      loadPackages =
        system: pkgs:
        import ./packages.nix (pkgs // { unstable = inputs.nixpkgs-unstable.legacyPackages.${system}; });
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: {
        default = (pkgsFor system).buildEnv {
          name = "shelffiles-env";
          # cacert is always included: entrypoint/env.sh points TLS clients at
          # its bundle so the environment does not depend on host certificates.
          paths = [
            (pkgsFor system).cacert
          ]
          ++ loadPackages system (pkgsFor system);
        };
      });
    };
}
