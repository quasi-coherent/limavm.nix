{ pkgs }:
{
  system,
  modules ? [ ],
}:
let
  evalConfig = import "${pkgs.path}/nixos/lib/eval-config.nix";
in
evalConfig {
  inherit system;
  modules = [
    ../options.nix
    ../lima.nix
  ]
  ++ modules;
}
