{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lima;
in
{
  options.lima = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Configure this NixOS system as a Lima guest.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.lima;
      defaultText = literalExpression "pkgs.lima";
    };

    settings = mkOption {
      type = (pkgs.formats.yaml { }).type;
      default = { };
      description = ''
        Additional settings to add to the `lima.yaml` runner config.
      '';
    };

    arch = mkOption {
      type = types.enum [
        "x86_64"
        "aarch64"
      ];
      default = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";
      defaultText = literalExpression "pkgs host arch";
      description = "Lima image arch label (matches the guest's CPU arch).";
    };

    vmType = mkOption {
      type = types.enum [
        "qemu"
        "vz"
      ];
      default = "qemu";
      description = ''
        Hypervisor Lima will use. `vz` requires macOS 13+ host (Apple
        Virtualization.framework). `qemu` works everywhere Lima runs.
      '';
    };

    cpus = mkOption {
      type = types.ints.positive;
      default = 2;
      description = "Number of vCPUs.";
    };

    memory = mkOption {
      type = types.str;
      default = "2GiB";
      description = "RAM (Lima size string, e.g. \"2GiB\").";
    };

    ssh = {
      loadDotSSHPubKeys = mkOption {
        type = types.bool;
        default = true;
        description = "Load host's ~/.ssh/*.pub into the guest's authorized_keys.";
      };
      localPort = mkOption {
        type = types.port;
        default = 0;
        description = "Host-side SSH port; 0 lets Lima pick.";
      };
    };

    disk = mkOption {
      type = types.str;
      default = "20GiB";
      description = "Disk size Lima reports to the guest.";
    };

    image = with lib; {
      diskSize = mkOption {
        type = types.either types.str types.ints.positive;
        default = "auto";
        description = "Image size passed to make-disk-image.";
      };
      additionalSpace = mkOption {
        type = types.str;
        default = "2G";
      };
      additionalPaths = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Extra store paths to include in the disk image closure.";
      };
    };

    mountType = mkOption {
      type = types.enum [
        "reverse-sshfs"
        "9p"
        "virtiofs"
      ];
      default = "reverse-sshfs";
      description = "Lima mount backend, which applies to all shares.";
    };

    mounts = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            location = mkOption {
              type = types.str;
              description = "Host path.";
            };
            writable = mkOption {
              type = types.bool;
              default = false;
            };
          };
        }
      );
      default = [ ];
      description = "Host directories exposed to the guest.";
    };

    portForwards = mkOption {
      type = types.listOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              guestPort = mkOption { type = types.port; };
              hostPort = mkOption {
                type = types.port;
                default = config.guestPort;
              };
              hostIP = mkOption {
                type = types.str;
                default = "127.0.0.1";
              };
            };
          }
        )
      );
      default = [ ];
    };

    provision = {
      system = mkOption {
        type = types.listOf types.lines;
        default = [ ];
        description = "Shell scripts run as root at boot.";
      };
      user = mkOption {
        type = types.listOf types.lines;
        default = [ ];
        description = "Shell scripts run as the lima user at boot.";
      };
    };

    rosetta.enabled = lib.mkEnableOption ''
      Whether Rosetta is available on the host to build x64 images.
      Requires MacOS > 13 host and the vmType to be "vz".
    '';
  };

  config = {
    assertions =
      let
        rosettaHasAppleVz = (cfg.rosetta.enabled && cfg.vmType == "vz") || !cfg.rosetta.enabled;
      in
      [
        {
          assertion = rosettaHasAppleVz;
          message = "`lima.rosetta.enabled = true` requires `lima.vmType` = \"vz\".";
        }
      ];
  };
}
