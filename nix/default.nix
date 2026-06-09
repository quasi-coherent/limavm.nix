{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./flakeModule.nix
  ];

  partitionedAttrs.checks = "dev";
  partitionedAttrs.devShells = "dev";
  partitionedAttrs.formatter = "dev";
  partitionedAttrs.packages = "dev";
  partitions.dev.extraInputsFlake = ../private;
  partitions.dev.module =
    { inputs, ... }:
    let
      inherit (inputs.nixpkgs.lib) mkIf;
    in
    {
      imports = [
        inputs.den.flakeModules.default
        inputs.actions-nix.flakeModules.default
        inputs.treefmt-nix.flakeModule
        ./ci
        ./den
        ./modules/den.nix
        ./private.nix
      ];

      perSystem =
        { inputs', system, ... }:
        let
          latest = import ./modules/base-image.nix { inherit (inputs'.nixpkgs) lib system; };
          stable = import ./modules/base-image.nix { inherit (inputs'.nixpkgs-stable) lib system; };
          packages = mkIf (system == "aarch64-linux" || system == "x86_64-linux") {
            inherit latest stable;
          };
        in
        {
          inherit packages;
        };
    };
}
