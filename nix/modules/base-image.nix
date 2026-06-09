{ lib, system, ... }:
(lib.nixosSystem {
  inherit system;
  modules = [ ../base-image.nix ];
}).config.system.build.limaImage
