{
  description = "Dev environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { utils, nixpkgs, ... }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        helm =
          with pkgs;
          wrapHelm kubernetes-helm {
            plugins = with kubernetes-helmPlugins; [
              helm-unittest
            ];
          };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            packages = [
              helm
              just
            ];
          };
      }
    );
}
