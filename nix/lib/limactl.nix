{
  coreutils,
  lib,
  lima,
  limaYaml,
  name ? "limavm-nix",
  writeShellApplication,
}:
writeShellApplication {
  name = "lctl-${name}";
  runtimeInputs = [
    coreutils
    lima
  ];
  text = ''
    export PATH=${
      lib.makeBinPath [
        coreutils
        lima
      ]
    }:$PATH

    export LIMA_INSTANCE="${name}"
    config="${limaYaml}"

    usage() {
      cat <<EOF
    lctl-${name} [COMMAND] [OPTIONS]
        'limactl' preconfigured for the VM ${name}

    Custom commands:
      create              Create an instance of Lima
      delete              Delete an instance of Lima
      list                List instances of Lima
      yaml                Print the Lima config that ${name} is using
      edit                Edit the instance of ${name}
      restart             Restart ${name}
      shell               Execute shell in ${name}
      start               Start an instance of ${name}
      rebuild             Rebuild the ${name} system
      stop                Stop the instance of ${name}
      shell               Execute shell in ${name}
      copy                Copy files between host and ${name}
      raw                 Forwards the remaining input to 'limactl'

      -h, --help, help           Show this message.
    EOF
    }

    cmd="''${1:-start}"
    shift || true

    case "$cmd" in
      -h|--help|help)
        usage
        ;;
      yaml)
        cat ${limaYaml}
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
        limactl start --tty=false --name="${name}" "$config" "$@"
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
      rebuild)
        limactl shell "${name}" sudo nixos-rebuild switch "$@"
        ;;
      copy|cp)
        limactl copy "$@"
        ;;
      raw)
        limactl "$@"
        ;;
      *)
        echo "Unknown command: $cmd" >&2
        usage >&2
        exit 1
        ;;
    esac
  '';
}
