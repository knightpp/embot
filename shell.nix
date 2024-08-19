{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  nativeBuildInputs = [pkgs.gnumake pkgs.cmake pkgs.gcc];
}
