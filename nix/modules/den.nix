{
  config,
  den,
  inputs,
  lib,
  ...
}:
let
  packages = (import ../lib).den.mkLimaPkgs {
    inherit
      config
      den
      inputs
      lib
      ;
  };
in
{
  config.flake.packages = packages;
}
