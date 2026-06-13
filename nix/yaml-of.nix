{
  pkgs,
  hostSystem,
}:
vm:
if vm.yaml != null then
  vm.yaml
else
  let
    # Default guest system map to the linux system with the same arch.
    # If the `rosetta.isEnabled` option is true, this maps a darwin system to
    # x64 instead.
    defaultGuestSystem =
      {
        "x86_64-linux" = "x86_64-linux";
        "aarch64-linux" = "aarch64-linux";
        "x86_64-darwin" = "x86_64-linux";
        "aarch64-darwin" = "aarch64-linux";
      }
      .${hostSystem};

    evalAt =
      system:
      import "${pkgs.path}/nixos/lib/eval-config.nix" {
        inherit system;
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];
            }
          )
          ./lima.nix
        ]
        ++ vm.guest.modules;
      };

    # Two-pass on aarch64-darwin: peek at rosetta to decide whether to flip
    # the guest to x86_64-linux. Elsewhere the default is final.
    initialEval = evalAt defaultGuestSystem;
    rosettaOn = hostSystem == "aarch64-darwin" && initialEval.config.lima.runner.rosetta.isEnabled;
    guestEval = if rosettaOn then evalAt "x86_64-linux" else initialEval;

    guestCfg = guestEval.config.lima;
    settings = guestEval.config.system.build.limaSettings;
    image =
      if vm.image != null then
        vm.image
      else if builtins.isString guestCfg.image then
        guestCfg.image
      else
        guestEval.config.system.build.limaImage;
    location = if builtins.isString image then image else "${image}/nixos.qcow2";
  in
  (pkgs.formats.yaml { }).generate "lima.yaml" (
    settings
    // {
      images = [
        {
          inherit (guestCfg.runner) arch;
          inherit location;
        }
      ];
    }
  )
