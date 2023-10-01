{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05.tar.gz") {} }:

pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.buildPackages.scons
    pkgs.buildPackages.dos2unix
    pkgs.buildPackages.moreutils
    pkgs.buildPackages.just
    pkgs.buildPackages.glow
    (pkgs.nushell.override { additionalFeatures = (p: ["dataframe"]); doCheck = false; })
  ];
}
