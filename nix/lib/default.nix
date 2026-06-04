{ lib }:
{
  yaml = import ./yaml.nix { inherit lib; };

  # Build the guest qcow2 image that Lima boots from.
  mkImage = args: import ./image.nix args;

  # Evaluate an ad-hoc NixOS guest configuration.
  evalGuest = pkgs: import ./eval-guest.nix { inherit pkgs; };

  # limactl wrapper pre-configured for an evaluated `options.lima`.
  limactl = ./limactl.nix;

  # Create the limactl wrapper for each den host that has activated this option.
  denPackage = ./den-package.nix;
}
