{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    lib.optionalAttrs (system == "aarch64-linux" || system == "x86_64-linux") {
      packages.lima-base-image =
        (inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ../base-image.nix ];
        }).config.system.build.limaImage;
    };
}
