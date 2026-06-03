{
  config,
  inputs,
  lib,
  ...
}:
let
  packages = (import ../lib).den.mkLimaPkgs { inherit config inputs lib; };
in
{
  config.flake.packages = packages;
}
