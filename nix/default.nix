{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModules.default
    ./flakeModules.nix
    ./checks.nix
  ];

  flake.templates = {
    standalone = {
      path = ./templates/standalone;
      description = "Intrinsic Lima VM definition in a package";
    };
    guests = {
      path = ./templates/guests;
      description = "Lima VMs defined as part of a nix-darwin";
    };
  };
}
