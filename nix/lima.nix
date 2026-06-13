{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  yamlFormat = pkgs.formats.yaml { };

  runner = {
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
    disk = mkOption {
      type = types.str;
      default = "20GiB";
      description = "Disk size Lima reports to the guest.";
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
    rosetta.isEnabled = lib.mkEnableOption ''
      Run an x86_64-linux guest on an aarch64-darwin host via Rosetta. When
      set, host orchestration flips the guest system to x86_64-linux and Lima
      enables Rosetta binfmt inside the VM. Requires macOS 13+ and
      `runner.vmType = "vz"`. No effect on non-aarch64-darwin hosts.
    '';
    arch = mkOption {
      type = types.enum [
        "x86_64"
        "aarch64"
      ];
      default = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";
      defaultText = lib.literalExpression "pkgs host arch";
      description = "Lima image arch label (matches the guest's CPU arch).";
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
    containerd = {
      system = mkOption {
        type = types.bool;
        default = false;
        description = "Enable containerd for the root user on the VM.";
      };
      user = mkOption {
        type = types.bool;
        default = false;
        description = "Enable containerd for the target user on the VM.";
      };
    };
    extraSettings = mkOption {
      inherit (yamlFormat) type;
      default = { };
      description = ''
        Freeform att
        Additional settings to add to the `lima.yaml` runner config.
      '';
    };
  };

  image = mkOption {
    type = types.either types.str (
      types.submodule {
        options = {
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
      }
    );
    default = { };
    description = ''
      Image source for the guest.  Either a URL/absolute path to a prebuilt qcow2, or
        a submodule of build args for `make-disk-image`.  The former doesn't build any
        image on the host.  The latter does, so has additional requirements of a darwin
        host system.
    '';
  };

  guest = {
    containerd.enable = lib.mkEnableOption "Whether to enable containerd virtualization in the guest";
    diskAutoResize = mkOption {
      type = types.bool;
      default = true;
      description = "Enable a `growpart` oneshot to resize up to `lima.runner.disk` on first boot.";
    };
    postBoot = mkOption {
      type = types.listOf (types.either types.str types.package);
      default = [ ];
      description = ''
        Scripts run by `lima-post-boot.service` after `lima-init.service`,
        in list order, by a single systemd oneshot. Strings are inlined;
        packages are executed via `lib.getExe`. The author is responsible
        for idempotency if a script shouldn't repeat across boots.
      '';
    };
  };
in
{
  options.lima = with lib; {
    inherit runner guest image;

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

    enabledForDenHost = mkOption {
      type = types.bool;
      default = false;
      internal = true;
      description = "Set by `den.batteries.toLima`; presence triggers mkLimactl.";
    };
  };

  config =
    let
      cfg = config.lima;
      lima-lib = import ./lib { inherit lib; };

      # A string-typed `lima.image` is a path to an existing nixos.qcow2.
      imageIsPrebuilt = builtins.isString cfg.image;

      limaSettings = {
        inherit (cfg.runner)
          vmType
          arch
          cpus
          memory
          disk
          mountType
          containerd
          ;
        mounts = map (m: { inherit (m) location writable; }) cfg.runner.mounts;
        portForwards = map (p: { inherit (p) guestPort hostPort hostIP; }) cfg.runner.portForwards;
        provision =
          map (s: {
            mode = "system";
            script = s;
          }) cfg.runner.provision.system
          ++ map (s: {
            mode = "user";
            script = s;
          }) cfg.runner.provision.user;
        rosetta = lib.optionalAttrs cfg.runner.rosetta.isEnabled {
          enabled = true;
          binfmt = true;
        };
        ssh = { inherit (cfg.runner.ssh) loadDotSSHPubKeys localPort; };
      }
      // cfg.runner.extraSettings;

      # Resolved `options.lima` but minus the image tag: keep this prop out of
      # the yaml to be able to build almost the whole config without having to
      # build the image too.
      evalSettings = yamlFormat.generate "settings.yaml" limaSettings;

      LIMA_CIDATA_MNT = "/mnt/lima-cidata";
      LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";

      assertions =
        let
          rosettaHasAppleVz =
            (cfg.runner.rosetta.isEnabled && cfg.runner.vmType == "vz") || !cfg.runner.rosetta.isEnabled;
          serialConsole =
            if cfg.runner.vmType == "vz" then
              "hvc0"
            else if cfg.runner.arch == "aarch64" then
              "ttyAMA0"
            else
              "ttyS0";
          hasSerialConsole = lib.any (p: lib.hasPrefix "console=${serialConsole}" p) config.boot.kernelParams;
        in
        [
          {
            assertion = rosettaHasAppleVz;
            message = "`lima.runner.rosetta.isEnabled = true` requires `lima.runner.vmType` = \"vz\".";
          }
          {
            assertion = hasSerialConsole;
            message = ''
              Lima needs a serial console kernel param (console=${serialConsole},115200)
              to produce useful boot logs in $LIMA_HOME/<vm>/serial.log. The guest
              module sets this by default but something in your config removed it.
            '';
          }
        ];
    in
    lib.mkIf cfg.enable {
      inherit assertions;

      system.build = {
        inherit evalSettings limaSettings;
      }
      // lib.optionalAttrs (!imageIsPrebuilt) {
        limaImage = lima-lib.mkImage {
          inherit pkgs lib config;
          imageCfg = cfg.image;
        };
      };

      nix.settings = {
        trusted-users = [ "@wheel" ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      environment.systemPackages =
        (with pkgs; [
          sshfs
          fuse3
        ])
        ++ lib.optional cfg.guest.containerd.enable pkgs.nerdctl;

      # Lima's reverse-sshfs backend mounts shares via `sshfs -o allow_other`,
      # which fuse rejects unless `user_allow_other` is uncommented in
      # /etc/fuse.conf. The other mount backends don't go through fuse.
      programs.fuse.userAllowOther = lib.mkDefault (cfg.runner.mountType == "reverse-sshfs");

      virtualisation.containerd.enable = cfg.guest.containerd.enable;

      services.openssh.enable = lib.mkDefault true;
      security.sudo.wheelNeedsPassword = lib.mkDefault false;

      boot.kernelParams = [
        "console=tty0"
        # Enable journal output to the serial console lima captures in
        # $LIMA_HOME/<vm>/serial.log.
        (
          if cfg.runner.vmType == "vz" then
            "console=hvc0"
          else if cfg.runner.arch == "aarch64" then
            "console=ttyAMA0,115200"
          else
            "console=ttyS0,115200"
        )
      ];

      # Overriding these makes the disk unbootable.
      boot.loader.grub.device = lib.mkForce "nodev";
      boot.loader.grub.efiSupport = lib.mkForce true;
      boot.loader.grub.efiInstallAsRemovable = lib.mkForce true;

      # Overriding either breaks the VM.
      fileSystems."/" = lib.mkForce {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      fileSystems."${LIMA_CIDATA_MNT}" = lib.mkForce {
        device = "${LIMA_CIDATA_DEV}";
        fsType = "auto";
        options = [
          "ro"
          "mode=0700"
          "dmode=0700"
          "overriderockperm"
          "exec"
          "uid=0"
        ];
      };

      # `mkForce` because nothing exists without it. Mostly adapted from:
      # https://github.com/lima-vm/alpine-lima/blob/ec4a135abbc8abecd21c2768e2bd7c260e11c6e9/lima-init.sh
      # https://github.com/nixos-lima/nixos-lima/blob/67bf50228688d79c98f6c0bc3a743dff2ce010bd/lima-init.nix
      systemd.services.lima-init = lib.mkForce {
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
          StandardOutput = "journal+console";
          StandardError = "journal+console";
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
          set -eux

          echo "attempting to fetch configuration from LIMA user data..."
          if [ -f ${LIMA_CIDATA_MNT}/lima.env ]; then
              echo "storage exists";
          else
              echo "storage does not exist";
              exit 2
          fi

          # Can't just `. lima.env` because it can contain spaces.
          while IFS= read -r line; do export "$line"; done < "${LIMA_CIDATA_MNT}/lima.env"

          : "''${LIMA_CIDATA_USER:?}"
          : "''${LIMA_CIDATA_UID:?}"
          : "''${LIMA_CIDATA_HOME:=/home/$LIMA_CIDATA_USER}"

          # Make /bin/bash resolvable so the user's login shell works
          # regardless of useradd's defaults.
          ln -sf /run/current-system/sw/bin/bash /bin/bash

          # NixOS sets UID_MIN=1000 / SYS_UID_MAX=999, so a Lima-supplied UID like
          # 503 falls outside both ranges and useradd skips creating the per-user
          # group. Create it explicitly so later `install -g $USER` succeeds.
          if ! getent group "$LIMA_CIDATA_USER" >/dev/null 2>&1; then
            groupadd --gid "$LIMA_CIDATA_UID" "$LIMA_CIDATA_USER"
          fi
          if ! id -u "$LIMA_CIDATA_USER" >/dev/null 2>&1; then
            useradd \
              --create-home \
              --home-dir "$LIMA_CIDATA_HOME" \
              --uid "$LIMA_CIDATA_UID" \
              --gid "$LIMA_CIDATA_USER" \
              --shell /run/current-system/sw/bin/bash \
              --groups wheel,users \
              "$LIMA_CIDATA_USER"
          fi

          # Lima 2.x writes pubkeys under `users: - name: … ssh-authorized-keys:`
          # (indented, hyphenated, quoted). This awk captures the indent of the
          # `ssh-authorized-keys:` line and then pulls every `- "..."` whose
          # indent is strictly deeper, stripping the surrounding quotes.
          SSHDIR="$LIMA_CIDATA_HOME/.ssh"
          install -d -m 700 -o "$LIMA_CIDATA_USER" -g "$LIMA_CIDATA_USER" "$SSHDIR"
          awk '
            match($0, /^([[:space:]]*)ssh-authorized-keys:[[:space:]]*$/, m) {
              prefix = "^" m[1] "[[:space:]]+-[[:space:]]+"
              flag = 1
              next
            }
            flag && $0 !~ prefix { flag = 0 }
            flag {
              line = $0
              sub(prefix, "", line)
              gsub("\"", "", line)
              print line
            }
          ' "${LIMA_CIDATA_MNT}/user-data" > "$SSHDIR/authorized_keys"
          chown "$LIMA_CIDATA_USER:$LIMA_CIDATA_USER" "$SSHDIR/authorized_keys"
          chmod 600 "$SSHDIR/authorized_keys"

          # Also copy to /etc/ssh/authorized_keys.d so an admin's AuthorizedKeysFile
          # picks it up regardless of $HOME.
          install -d -m 755 /etc/ssh/authorized_keys.d
          install -m 644 "$SSHDIR/authorized_keys" \
            "/etc/ssh/authorized_keys.d/$LIMA_CIDATA_USER"

          if [ -d "${LIMA_CIDATA_MNT}/provision.system" ]; then
            for f in "${LIMA_CIDATA_MNT}/provision.system"/*; do
              [ -x "$f" ] || continue
              echo "running $f"
              "$f" || echo "provision script $f failed (continuing)"
            done
          fi

          : "''${LIMA_CIDATA_IID:=unknown}"
          printf '%s\n' "$LIMA_CIDATA_IID" > /run/lima-boot-done
          printf '%s\n' "$LIMA_CIDATA_IID" > /run/lima-ssh-ready
        '';
      };

      systemd.services.lima-guestagent = lib.mkForce {
        description = "Lima guest agent";
        wantedBy = [ "multi-user.target" ];
        after = [ "lima-init.service" ];
        requires = [ "lima-init.service" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = 3;
        };
        script = ''
          set -eu
          while IFS= read -r line; do export "$line"; done < /mnt/lima-cidata/lima.env
          exec /mnt/lima-cidata/lima-guestagent daemon \
            --vsock-port "$LIMA_CIDATA_VSOCK_PORT"
        '';
      };

      # Generic post-boot oneshot.
      systemd.services.lima-post-boot = lib.mkIf (cfg.guest.postBoot != [ ]) {
        description = "Lima post-boot user scripts";
        after = [ "lima-init.service" ];
        requires = [ "lima-init.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
        script = lib.concatStringsSep "\n" (
          map (s: if builtins.isString s then s else "${lib.getExe s}") cfg.guest.postBoot
        );
      };

      # Lima reports `runner.disk` to the hypervisor, but the qcow2 we boot from
      # was built smaller. Without this, the root filesystem stays at the image's
      # size and the extra space is wasted.
      systemd.services.lima-grow-rootfs = lib.mkIf cfg.guest.diskAutoResize {
        description = "Resize root filesystem to fill Lima-reported disk";
        wantedBy = [ "local-fs.target" ];
        before = [
          "local-fs.target"
          "lima-init.service"
        ];
        after = [ "systemd-udev-settle.service" ];
        path = with pkgs; [
          cloud-utils
          parted
          e2fsprogs
          util-linux
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -eu
          root_dev=$(findmnt -no SOURCE /)
          disk=/dev/$(lsblk -no PKNAME "$root_dev")
          part=''${root_dev##*[!0-9]}
          growpart "$disk" "$part" || true
          resize2fs "$root_dev" || true
        '';
      };
    };
}
