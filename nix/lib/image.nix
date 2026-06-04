{
  pkgs,
  lib,
  config,
  imageCfg,
}:
import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
  inherit pkgs lib config;
  format = "qcow2";
  partitionTableType = "efi";
  diskSize = imageCfg.diskSize;
  additionalSpace = imageCfg.additionalSpace;
  additionalPaths = imageCfg.additionalPaths;
  label = "nixos";
  installBootLoader = true;
  touchEFIVars = false;
}
