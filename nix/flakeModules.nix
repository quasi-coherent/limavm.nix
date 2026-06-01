let
  limavm = ./limavm;
  default = limavm;
in
{
  flake = {
    flakeModules.limaLib = ./den;
    nixosModules = {
      inherit limavm default;
      host = ./host/nixos.nix;
    };
    darwinModules = {
      inherit limavm default;
      host = ./host/darwin.nix;
    };
  };
}
