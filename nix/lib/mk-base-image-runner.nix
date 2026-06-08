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
  rebuildScript = import ./mk-bootstrap-script.nix {
    inherit flake attr marker;
  };
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
