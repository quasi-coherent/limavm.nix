{
  pkgs,
  system,
  modules ? [ ],
}:
let
  evalConfig = import "${pkgs.path}/nixos/lib/eval-config.nix";
  guest = evalConfig {
    inherit system;
    modules = [
      ../options.nix
      ../lima.nix
    ]
    ++ modules;
  };
in
guest.config.system.build.limaYaml
