{ ... }:
{
  # Build the guest qcow2 image that Lima boots from.
  mkImage = args: import ./image.nix args;

  # Extend an existing `nixosSystem` with the Lima guest provisioning module
  # (`nix/lima.nix`) and the given `lima` settings. Returns a new evaluated
  # `nixosSystem` whose `config.system.build.{limaImage,limaSettings}` are
  # populated.
  mkLimaGuest = import ./mk-lima-guest.nix;

  # Bundle the per-guest derivations from a nixosSystem that has Lima guest
  # provisioning enabled (via `nixosModules.guest` or `lib.mkLimaGuest`):
  # { image, yaml, start }. `image` is null when `lima.image` is a string ref
  # to a prebuilt qcow2.
  limavmPackages = import ./limavm-packages.nix;
}
