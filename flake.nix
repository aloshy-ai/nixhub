{
  description = "𝓷𝓲𝔁🅷🆄🅱 - An open-source custom Nix scripts repository. Read source before execute!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # Add default package
        packages.default = pkgs.buildEnv {
          name = "nixhub";
          paths = [ ]; # Empty since this is just a development environment
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixfmt-rfc-style
            nodejs_20
            watchexec
            parallel
            direnv
            husky
            curl
            just
            git
            jq
            gh
          ];

          shellHook = ''
            npm i
            chmod +x ./run
            chmod +x ./scripts/*
            chmod +x ./scripts/tests/*
            echo "░░░░░░░░░░  𝓷𝓲𝔁🅷🆄🅱  ░░░░░░░░░░"
          '';
        };

        formatter = pkgs.nixpkgs-fmt;
      });
}
