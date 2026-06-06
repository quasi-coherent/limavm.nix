{ pkgs }:
vm:
if vm.yaml != null then
  vm.yaml
else
  let
    guestEval = import ./eval-guest.nix {
      inherit pkgs;
      inherit (vm.guest) system modules;
    };
    guestCfg = guestEval.config.lima;
    settings = guestEval.config.system.build.limaSettings;
    image =
      if vm.image != null then
        vm.image
      else if builtins.isString guestCfg.image then
        guestCfg.image
      else
        guestEval.config.system.build.limaImage;
  in
  import ./with-image.nix {
    inherit pkgs image;
    inherit (guestCfg) arch;
  } settings
