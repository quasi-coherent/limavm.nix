{ config, pkgs, ... }:
let
  inherit (pkgs) lib;

  cfg = config.lima;

  limaImage = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
    inherit pkgs lib config;
    format = "qcow2";
    partitionTableType = "efi";
    diskSize = cfg.image.diskSize;
    additionalSpace = cfg.image.additionalSpace;
    additionalPaths = cfg.image.additionalPaths;
    label = "nixos";
    installBootLoader = true;
    touchEFIVars = false;
  };

  limaSettings = lib.mkIf cfg.enable {
    inherit (cfg)
      vmType
      arch
      cpus
      memory
      disk
      ;

    mountType = cfg.mountType;
    mounts = map (m: { inherit (m) location writable; }) cfg.mounts;

    portForwards = map (p: {
      inherit (p) guestPort hostPort hostIP;
    }) cfg.portForwards;

    provision =
      map (s: {
        mode = "system";
        script = s;
      }) cfg.provision.system
      ++ map (s: {
        mode = "user";
        script = s;
      }) cfg.provision.user;

    rosetta = lib.mkIf cfg.rosetta.enabled {
      enabled = true;
      binfmt = true;
    };

    ssh = { inherit (cfg.ssh) loadDotSSHPubKeys localPort; };
  };
in
{
  inherit limaImage limaSettings;
}
