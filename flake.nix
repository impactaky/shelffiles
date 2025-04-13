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
          packagesPath = ./config/nix/packages.nix;
        in import packagesPath pkgs;
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Use mkDerivation to build the environment and copy project files
          shelffilesPkg = pkgs.stdenv.mkDerivation {
            name = "shelffiles";
            src = ./.; # Access project files

            # Nix packages needed in the environment
            buildInputs = loadPackages system pkgs;

            # Commands to copy project files into the derivation ($out)
            installPhase = ''
              mkdir -p $out/shelffiles

              echo "Copying entrypoint and config..."
              cp -r $src/entrypoint $out/shelffiles/
              cp -r $src/config $out/shelffiles/
              echo "Done copying."
            '';

            # Ensure necessary tools like cp and mkdir are available
            nativeBuildInputs = [ pkgs.coreutils ];

            # Prevent default phases we don't need or want to override
            dontBuild = true;
            dontConfigure = true;
            # unpackPhase might need adjustment if src isn't just files/dirs
          };
        in {
          # The main package now includes the environment and copied files
          default = shelffilesPkg;
          # Remove the separate start-shelffiles package
        });

      # Add the apps output
      apps = nixpkgs.lib.genAttrs systems (system:
        let
          # Reference the main package defined above
          shelffilesPkg = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            # Point program to the bash entrypoint script inside the copied dir
            program = "${shelffilesPkg}/shelffiles/entrypoint/bash";
          };
        });
    };
}
