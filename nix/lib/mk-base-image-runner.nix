{
  pkgs,
  name,
  baseImage,
  flake,
  attr,
  settings ? { },
  arch ? if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64",
  marker ? "/var/lib/lima-bootstrap.done",
}:
let
  rebuildScript = ''
    set -eu
    MARKER=${marker}
    if [ -f "$MARKER" ]; then
      echo "lima-base-runner: already converged ($MARKER)"
      exit 0
    fi
    nixos-rebuild switch --flake "${flake}#${attr}"
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
  '';
  finalSettings = settings // {
    provision = (settings.provision or [ ]) ++ [
      {
        mode = "system";
        script = rebuildScript;
      }
    ];
  };
  yaml = import ./with-image.nix {
    inherit pkgs arch;
    image = baseImage;
    name = "${name}-lima.yaml";
  } finalSettings;
  start = pkgs.callPackage ./limactl.nix {
    limaYaml = yaml;
    inherit name;
  };
in
{
  image = null;
  inherit yaml start;
}
