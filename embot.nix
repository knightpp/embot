{
  beam,
  lib,
  cmake,
}: let
  beamPackages = beam.packagesWith beam.interpreters.erlang;
in
  beamPackages.mixRelease {
    pname = "embot";

    version = "0.0.1";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.gitTracked ./.;
    };

    # mixFodDeps = beamPackages.fetchMixDeps {
    #   pname = "mix-deps-${pname}";
    #   inherit src version;
    #   hash = "sha256-7RFFr70bawpbgZTmGb+D01dbGcgCT9EujmT6H9TKxHs=";
    # };

    # env = {
    #   HTML5EVER_BUILD = "1";
    #   RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "1";
    #   # RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "$TMP";
    # };

    mixNixDeps = import ./deps.nix {
      inherit lib beamPackages;
      overrides = final: prev: {
        fast_html = prev.fast_html.override {
          buildInputs = [cmake];
        };
      };
    };
  }
