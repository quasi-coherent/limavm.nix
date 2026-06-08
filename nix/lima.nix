{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  LIMA_CIDATA_MNT = "/mnt/lima-cidata";
  LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";

  cfg = config.lima;
  lima-lib = import ./lib { inherit lib; };

  limaSettings = lima-lib.yaml.mkLimaSettings cfg;

  evalYaml = lima-lib.yaml.renderYaml pkgs "eval.yaml" limaSettings;

  imageIsPrebuilt = builtins.isString cfg.image;
in
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  config =
    let
      assertions =
        let
          rosettaHasAppleVz = (cfg.rosetta.enabled && cfg.vmType == "vz") || !cfg.rosetta.enabled;
          serialConsole = if cfg.arch == "aarch64" then "ttyAMA0" else "ttyS0";
          hasSerialConsole = lib.any (p: lib.hasPrefix "console=${serialConsole}" p) config.boot.kernelParams;
        in
        [
          {
            assertion = rosettaHasAppleVz;
            message = "`lima.rosetta.enabled = true` requires `lima.vmType` = \"vz\".";
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
        inherit evalYaml limaSettings;
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

      environment.systemPackages = with pkgs; [
        sshfs
        fuse3
      ];

      services.openssh.enable = lib.mkDefault true;
      security.sudo.wheelNeedsPassword = lib.mkDefault false;

      boot.kernelParams = [
        "console=tty0"
        # Enable journal output to serial console because that's where the useful
        # debugging logs go for QEMU ($LIMA_HOME/<vm>/serial.log).
        (if cfg.arch == "aarch64" then "console=ttyAMA0,115200" else "console=ttyS0,115200")
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

      # Mostly adapted from:
      # https://github.com/lima-vm/alpine-lima/blob/ec4a135abbc8abecd21c2768e2bd7c260e11c6e9/lima-init.sh
      # https://github.com/nixos-lima/nixos-lima/blob/67bf50228688d79c98f6c0bc3a743dff2ce010bd/lima-init.nix
      # `mkForce` because nothing exists without it.
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
              echo "storage not exists";
              exit 2
          fi

          # Source lima.env defensively: values can contain spaces, so we
          # can't just `. lima.env`.
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

          # Belt-and-braces: also drop a copy in /etc/ssh/authorized_keys.d
          # so an admin-set AuthorizedKeysFile picks it up regardless of $HOME.
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

          # Lima ≥2.1 readiness signal: the IID goes INTO these files, not
          # into their filename. Lima polls both before declaring the VM up.
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
      systemd.services.lima-post-boot = lib.mkIf (cfg.postBoot != [ ]) {
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
          map (s: if builtins.isString s then s else "${lib.getExe s}") cfg.postBoot
        );
      };

    };
}
