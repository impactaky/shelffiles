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

      # Generate environment setup script
      generateEnv = pkgs: packages:
        let
          # Extract package names from the package list
          packageNames = map (pkg: pkg.pname or pkg.name) packages;
          packageList = builtins.concatStringsSep " " packageNames;
        in
        pkgs.stdenv.mkDerivation {
          name = "shelffiles-env-generator";
          src = ./.;

          buildPhase = ''
            # Create output directory
            mkdir -p $out/share/shelffiles

            # Run the generate_env.sh script with package names
            sh ./generate_env.sh $out/share/shelffiles/generated_env.sh ${packageList}
          '';

          installPhase = ''
            # The script already creates files in the correct location
            true
          '';
        };
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          packages = loadPackages system pkgs;
          generatedEnv = generateEnv pkgs packages;
        in {
          default = pkgs.buildEnv {
            name = "shelffiles-env";
            paths = packages ++ [ generatedEnv ];
          };
        }
      );
    };
}
