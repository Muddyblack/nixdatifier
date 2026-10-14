# The nixpkgs-style packages, laid out like pkgs/by-name in nixpkgs. They fetch
# a tagged release from GitHub instead of building the working tree.
#
#   nix-build nix/nixpkgs -A nixdatifier
#   nix-update --file nix/nixpkgs nixdatifier --version 2.2.0   # bump version and hash
#
# The release workflow does the second step for you (see docs/packaging.md).
{
  pkgs ? import <nixpkgs> { },
}:
{
  nixdatifier = pkgs.callPackage ./nixdatifier/package.nix { };
  nixdatifier-cli = pkgs.callPackage ./nixdatifier-cli/package.nix { };
}
