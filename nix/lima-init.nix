{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  cfg = config.lima;

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
in
{
  # Don't know what this does but it fails without it, and that's annoying
  # because of `modulesPath`.
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  # Mostly adapted from:
  # https://github.com/lima-vm/alpine-lima/blob/ec4a135abbc8abecd21c2768e2bd7c260e11c6e9/lima-init.sh
  # https://github.com/nixos-lima/nixos-lima/blob/67bf50228688d79c98f6c0bc3a743dff2ce010bd/lima-init.nix
  config = lib.mkIf cfg.enable {
    system.build = { inherit limaImage limaYaml; };

    nix.settings = {
      trusted-users = [ "@wheel" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Lima needs these, pretty sure.
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
