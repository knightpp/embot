{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    allSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    # Helper to provide system-specific attributes
    forAllSystems = f:
      nixpkgs.lib.genAttrs allSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
        });
  in {
    packages = forAllSystems ({pkgs}: rec {
      default = embot;
      embot = pkgs.callPackage ./embot.nix {};

      deps = pkgs.writeShellScriptBin "generate-deps-nix" ''
        ${pkgs.mix2nix}/bin/mix2nix > deps.nix
      '';
    });

    devShells = forAllSystems ({pkgs}: {
      default = pkgs.mkShell {
        nativeBuildInputs = [pkgs.gnumake pkgs.cmake pkgs.gcc];
      };
    });
  };
}
