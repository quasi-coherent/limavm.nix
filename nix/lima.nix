{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  cfg = config.lima;
in
{

  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

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

    runner = mkOption {
      type = types.bool;
      default = false;
      internal = true;
      description = "Set by `den.batteries.toLima`; presence triggers mkLimactl.";
    };

    runnerSystems = mkOption {
      type = types.listOf types.str;
      default = [ ];
      defaultText = literalExpression ''[ "''${arch}-darwin" "''${arch}-linux" ]'';
      description = ''
        Systems where the `limactl` wrapper package is emitted. Empty list
        means use the default (host arch on both darwin and linux).
      '';
    };
  };

  config =
    let
      # The image the Lima boots from.
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

      # Serialized as yaml for the `nixos.yaml` that `limactl` needs.
      limaSettings = {
        inherit (cfg)
          vmType
          arch
          cpus
          memory
          disk
          ;

        images = [
          {
            location = "${limaImage}/nixos.qcow2";
            inherit (cfg) arch;
          }
        ];

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

      # The VM configuration for limactl.
      limaYaml = (pkgs.formats.yaml { }).generate "lima.yaml" limaSettings;

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
    in
    lib.mkIf cfg.enable {
      inherit assertions;

      # Hard-coded nixosSystem options that Lima fails to boot without:
      system.build = { inherit limaImage limaYaml; };

      nix.settings = {
        trusted-users = [ "@wheel" ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      services.openssh.enable = true;
      security.sudo.wheelNeedsPassword = false;

      boot = {
        kernelParams = [ "console=tty0" ];
        loader.grub = {
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
        loader.systemd-boot.enable = true;
      };

      environment.systemPackages = with pkgs; [
        sshfs
        fuse3
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      fileSystems."/mnt/lima-cidata" = {
        device = "/dev/disk/by-label/cidata";
        fsType = "iso9660";
        options = [
          "ro"
          "nofail"
        ];
      };

      # Mostly adapted from:
      # https://github.com/lima-vm/alpine-lima/blob/ec4a135abbc8abecd21c2768e2bd7c260e11c6e9/lima-init.sh
      # https://github.com/nixos-lima/nixos-lima/blob/67bf50228688d79c98f6c0bc3a743dff2ce010bd/lima-init.nix
      systemd.services.lima-init = {
        description = "Lima cloud-init bootstrap";
        after = [
          "local-fs.target"
          "network-pre.target"
        ];
        before = [ "sshd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = with pkgs; [
          shadow
          openssh
          coreutils
          gnused
          gawk
          gnugrep
          util-linux
        ];
        script = ''
          set -eu
          CIDATA=/mnt/lima-cidata
          if [ ! -r "$CIDATA/lima.env" ]; then
            echo "lima.env missing under $CIDATA; not a Lima boot?" >&2
            exit 0
          fi
          # shellcheck disable=SC1091
          . "$CIDATA/lima.env"
          : "''${LIMA_CIDATA_USER:?}"
          : "''${LIMA_CIDATA_UID:?}"
          : "''${LIMA_CIDATA_HOME:=/home/$LIMA_CIDATA_USER}"

          if ! id -u "$LIMA_CIDATA_USER" >/dev/null 2>&1; then
            useradd -m -d "$LIMA_CIDATA_HOME" -u "$LIMA_CIDATA_UID" -G wheel,users "$LIMA_CIDATA_USER"
          fi

          mkdir -p "$LIMA_CIDATA_HOME/.ssh"
          chmod 700 "$LIMA_CIDATA_HOME/.ssh"
          awk '/^ssh_authorized_keys:/{flag=1; next} flag && /^[^[:space:]-]/{flag=0} flag && /^- /' "$CIDATA/user-data" \
            | sed 's/^- //' > "$LIMA_CIDATA_HOME/.ssh/authorized_keys" || true
          chmod 600 "$LIMA_CIDATA_HOME/.ssh/authorized_keys"
          chown -R "$LIMA_CIDATA_USER:$LIMA_CIDATA_USER" "$LIMA_CIDATA_HOME/.ssh"

          if [ -d "$CIDATA/provision.system" ]; then
            for f in "$CIDATA/provision.system"/*; do
              [ -x "$f" ] && "$f" || true
            done
          fi

          mkdir -p /run
          if [ -n "''${LIMA_CIDATA_IID:-}" ]; then
            : > "/run/lima-boot-done-$LIMA_CIDATA_IID"
          else
            : > /run/lima-boot-done
          fi
          : > /run/lima-ssh-ready
        '';
      };

      systemd.services.lima-guestagent = {
        description = "Lima guest agent";
        after = [ "lima-init.service" ];
        requires = [ "lima-init.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          ExecStart = pkgs.writeShellScript "lima-guestagent-run" ''
                set -eu
            . /mnt/lima-cidata/lima.env
            exec /mnt/lima-cidata/lima-guestagent daemon \
              --vsock-port "$LIMA_CIDATA_VSOCK_PORT"
          '';
        };
      };
    };
}
