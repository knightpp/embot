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
    packages = forAllSystems ({pkgs}: let
      mkImage = {
        package,
        name,
        tag,
      }:
        pkgs.dockerTools.buildImage {
          inherit name;
          inherit tag;

          compressor = "zstd";
          copyToRoot = [package];

          config = {
            Cmd = ["${package}/bin/embot" "start"];
          };
        };
      embot = pkgs.callPackage ./package.nix {};
    in {
      default = embot;
      inherit embot;

      image = mkImage {
        package = embot;
        name = "embot";
        tag = "dev";
      };

      release-image = mkImage {
        package = embot;
        name = "registry.fly.io/app-spring-dawn-4138";
        tag = "latest";
      };
    });

    devShells = forAllSystems ({pkgs}: {
      default = pkgs.mkShell {
        nativeBuildInputs = [pkgs.flyctl];
      };
    });
  };
}
