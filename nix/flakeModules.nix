let
  lima = ./limavm;
  default = lima;
in
{
  flake = {
    flakeModules = {
      inherit lima default;
      limaLib = ./den;
    };
    nixosModules.host = ./host/nixos.nix;
    darwinModules.host = ./host/darwin.nix;
  };
}
