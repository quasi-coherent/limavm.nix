{
  pkgs,
  name,
  settings,
  image,
  arch,
}:
let
  withImage = import ./with-image.nix;
  yaml = withImage {
    inherit pkgs image arch;
    name = "${name}-lima.yaml";
  } settings;
  start = pkgs.callPackage ./limactl.nix {
    limaYaml = yaml;
    inherit name;
  };
  imageOut = if builtins.isString image then null else image;
in
{
  image = imageOut;
  inherit yaml start;
}
