let
  lima = ./den;
in
{
  flake = {
    flakeModules = {
      inherit lima;
      default = lima;
    };
    nixosModules.host = ./host/nixos.nix;
    nixosModules.guest = ./limavm;
    darwinModules.host = ./host/darwin.nix;
  };
}
