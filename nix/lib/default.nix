{ lib }:
{
  yaml = import ./yaml.nix { inherit lib; };

  # Build the guest qcow2 image that Lima boots from.
  mkImage = args: import ./image.nix args;

  # Evaluate an ad-hoc NixOS guest configuration.
  evalGuest = import ./eval-guest.nix;

  # Render a final lima.yaml derivation from image-less settings + an image
  # reference (string URL/path or a built image derivation). This is the only
  # path to an image-embedded YAML.
  withImage = import ./with-image.nix;

  # Resolve the final lima.yaml of a guest VM defined on a host.
  yamlOf = import ./yaml-of.nix;

  # Bundle the three per-guest derivations from a nixosSystem that imports
  # `nixosModules.guest`: { image, yaml, start }. `image` is null when the
  # nixosSystem's `lima.image` is a string ref to a prebuilt qcow2.
  mkGuestPackages = import ./mk-guest-packages.nix;

  # Bundle the same { image = null; yaml; start } trio, but for a prebuilt image
  # that is rebuilt via `nixos-rebuild switch --flake $flake#$attr` on the first
  # boot.
  mkBaseImageRunner = import ./mk-base-image-runner.nix;

  # Rebuild-on-first-boot shell script for the bootstrap path. Used by the
  # guest module (via `lima.bootstrap`) and by `mkBaseImageRunner`.
  mkBootstrapScript = import ./mk-bootstrap-script.nix;

  # limactl wrapper pre-configured for an evaluated `options.lima`.
  limactl = ./limactl.nix;

  # Create the limactl wrapper for each den host that has activated this option.
  denPackage = ./den-package.nix;
}
