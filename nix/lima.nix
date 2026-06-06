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

      system.build = {
        inherit evalYaml limaSettings;
      }
      // lib.optionalAttrs (!imageIsPrebuilt) {
        limaImage = lima-lib.mkImage {
          inherit pkgs lib config;
          imageCfg = cfg.image;
        };
      };

      # Hard-coded nixosSystem options that Lima fails to boot without:
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
        kernelParams = [
          "console=tty0"
          # Enable journal output to serial console because that's where the useful
          # debugging logs go for QEMU ($LIMA_HOME/<vm>/serial.log).
          (if cfg.arch == "aarch64" then "console=ttyAMA0,115200" else "console=ttyS0,115200")
        ];
        loader.grub = {
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
      };

      environment.systemPackages = with pkgs; [
        sshfs
        fuse3
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      fileSystems."${LIMA_CIDATA_MNT}" = {
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

      systemd.services.lima-guestagent = {
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

      # Define this always so that a plain base image gets the limactl runner
      # like it would if there were a user-supplied bootstrap.
      systemd.services.lima-bootstrap = {
        description = "Lima bootstrap: nixos-rebuild into the consumer's flake";
        after = [
          "lima-init.service"
          "network-online.target"
        ];
        requires = [ "lima-init.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = "/etc/lima-bootstrap/env";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
        path = with pkgs; [
          nixos-rebuild
          git
          coreutils
          nix
        ];
        script = ''
          set -eu
          . /etc/lima-bootstrap/env
          : "''${FLAKE:?}"
          : "''${ATTR:?}"
          MARKER="''${MARKER:-/var/lib/lima-bootstrap.done}"
          if [ "''${RUN_ONCE:-true}" = "true" ] && [ -f "$MARKER" ]; then
            echo "lima-bootstrap: already converged ($MARKER exists)"
            exit 0
          fi
          nixos-rebuild switch --flake "$FLAKE#$ATTR"
          mkdir -p "$(dirname "$MARKER")"
          touch "$MARKER"
        '';
      };

      # When the consumer has set `lima.bootstrap.flake`, emit a `provision`
      # script to write the env file for the `lima-bootstrap` systemd unit.
      # Has to be placed last in the list of `lima.provision.system` scripts so
      # that any user-supplied ones run first.
      lima.provision.system = lib.mkIf (cfg.bootstrap.flake != null) (
        lib.mkAfter [
          ''
            set -eu
            mkdir -p /etc/lima-bootstrap
            cat > /etc/lima-bootstrap/env <<EOF
            FLAKE=${cfg.bootstrap.flake}
            ATTR=${cfg.bootstrap.attr}
            MARKER=${cfg.bootstrap.markerFile}
            RUN_ONCE=${if cfg.bootstrap.runOnce then "true" else "false"}
            EOF
          ''
        ]
      );
    };
}
