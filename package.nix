{
  lib,
  elixir,
  beamPackages,
}: let
  pname = "embot";
  version = "unstable";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.gitTracked ./.;
  };
in
  beamPackages.mixRelease {
    inherit
      pname
      version
      src
      elixir
      ;

    stripDebug = true;
    removeCookie = false;

    mixFodDeps = beamPackages.fetchMixDeps {
      pname = "mix-deps-${pname}";
      inherit src version elixir;
      hash = "sha256-MsBSkN9eNC/mdO7qxVUF5CLQbzq8UiwKY473Mk9ZkbE=";
    };

    meta = {
      homepage = "https://github.com/elixir-lsp/elixir-ls";
      license = lib.licenses.mit;
      platforms = lib.platforms.unix;
      mainProgram = "embot";
      maintainers = with lib.maintainers; [knightpp];
    };
  }
