{
  pkgs,
  name,
  nixosSystem,
  # `nixosConfigurations.<attr>` <--> `nixos-rebuild switch --flake .#<attr>`
  # If this is null, just use the pre-built image.
  guestSystem ? name,
}:
let
  inherit (pkgs) lib;
  lima = nixosSystem.config.lima;
  settings = nixosSystem.config.system.build.limaSettings;
  image =
    if builtins.isString lima.image then lima.image else nixosSystem.config.system.build.limaImage;
  location = if builtins.isString image then image else "${image}/nixos.qcow2";

  # Inlined image-embedding: stitch the chosen image into the settings yaml.
  yaml = (pkgs.formats.yaml { }).generate "${name}-lima.yaml" (
    settings
    // {
      images = [
        {
          inherit (lima.runner) arch;
          inherit location;
        }
      ];
    }
  );

  rebuildBlock = ''
    flake_dir="''${flake_dir:-$PWD}"
    if [ ! -e "$flake_dir/flake.nix" ]; then
      echo "${name}-lima: no flake.nix at $flake_dir; skipping rebuild" >&2
      exit 1
    fi
    export NIX_SSHOPTS="-F $LIMA_HOME/${name}/ssh.config"
    nh os switch \
      --hostname "${toString guestSystem}" \
      --target-host "lima-${name}" \
      --build-host "lima-${name}" \
      "$flake_dir" "$@"
  '';

  limaPackage = lima.package or pkgs.lima;

  start = pkgs.writeShellApplication {
    name = "${name}-lima";
    runtimeInputs = [
      pkgs.coreutils
      limaPackage
      pkgs.nh
    ];
    text = ''
      export PATH=${
        lib.makeBinPath [
          pkgs.coreutils
          limaPackage
          pkgs.nh
        ]
      }:$PATH

      export LIMA_INSTANCE="${name}"
      if [ -n "''${LIMA_HOME:-}" ]; then
        mkdir -p "$LIMA_HOME"
      fi
      config="${yaml}"

      usage() {
        cat <<EOF
      ${name}-lima [COMMAND] [OPTIONS]
          'limactl' preconfigured for the VM ${name}

      Custom commands:
        create                Create an instance of Lima
        delete                Delete an instance of Lima
        list                  List instances of Lima
        yaml                  Print the Lima config that ${name} is using
        edit                  Edit the instance of ${name}
        restart               Restart ${name}
        shell                 Execute shell in ${name}
        start [--flake DIR]   Start ${name}${
          if guestSystem != null then
            " and rebuild to nixosConfigurations.${guestSystem} (default flake dir: \\$PWD)"
          else
            ""
        }
        ${
          if guestSystem != null then
            "rebuild [--flake DIR] Rebuild the running guest to nixosConfigurations.${guestSystem}"
          else
            ""
        }
        stop                  Stop the instance of ${name}
        copy                  Copy files between host and ${name}
        lctl                  Forwards the remaining input to 'limactl'
        nh                    Forwards the remaining input to 'nh'

        -h, --help, help      Show this message.
      EOF
      }

      cmd="''${1:-start}"
      shift || true

      parse_flake() {
        flake_dir=""
        extra_args=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --flake)
              shift
              flake_dir="''${1:-}"
              shift || true
              ;;
            *)
              extra_args+=("$1")
              shift
              ;;
          esac
        done
      }

      case "$cmd" in
        -h|--help|help)
          usage
          ;;
        yaml)
          cat ${yaml}
          ;;
        create)
          limactl create --tty=false --name="${name}" "$config" "$@"
          ;;
        delete)
          limactl delete "${name}" "$@"
          ;;
        list|ls)
          limactl list "$@"
          ;;
        edit)
          limactl edit "${name}" "$@"
          ;;
        start)
          parse_flake "$@"
          set -- "''${extra_args[@]}"
          limactl start --tty=false --name="${name}" "$config" "$@"
          ${lib.optionalString (guestSystem != null) rebuildBlock}
          ;;
        stop)
          limactl stop "${name}" "$@"
          ;;
        restart)
          limactl stop "${name}" || true
          limactl start --tty=false --name="${name}" "$config"
          ;;
        shell)
          limactl shell "${name}" "$@"
          ;;
        ${lib.optionalString (guestSystem != null) ''
          rebuild)
            parse_flake "$@"
            set -- "''${extra_args[@]}"
            ${rebuildBlock}
            ;;
        ''}
        copy|cp)
          limactl copy "$@"
          ;;
        lctl)
          limactl "$@"
          ;;
        nh)
          nh "$@"
          ;;
        *)
          echo "Unknown command: $cmd" >&2
          usage >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  image = if builtins.isString image then null else image;
  inherit yaml start;
}
