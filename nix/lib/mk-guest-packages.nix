{
  pkgs,
  name,
  nixosSystem,
  # `nixosConfigurations.<attr>` <--> `nixos-rebuild switch --flake .#<attr>`
  # If this is null, just use the pre-built image.
  guestSystem ? name,
}:
let
  lima = nixosSystem.config.lima;
  settings = nixosSystem.config.system.build.limaSettings;
  image =
    if builtins.isString lima.image then lima.image else nixosSystem.config.system.build.limaImage;
  yaml = import ./with-image.nix {
    inherit pkgs image;
    inherit (lima) arch;
    name = "${name}-lima.yaml";
  } settings;
  start = pkgs.callPackage ./limactl.nix {
    limaYaml = yaml;
    inherit name guestSystem;
    inherit (lima) limaHomeDir;
  };
in
{
  image = if builtins.isString image then null else image;
  inherit yaml start;
}
