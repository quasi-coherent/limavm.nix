{
  pkgs,
  image,
  arch,
  name ? "lima.yaml",
}:
settings:
let
  location = if builtins.isString image then image else "${image}/nixos.qcow2";
  withImages = settings // {
    images = [
      {
        inherit arch location;
      }
    ];
  };
in
(pkgs.formats.yaml { }).generate name withImages
