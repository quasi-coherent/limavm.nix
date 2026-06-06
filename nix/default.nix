{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./flakeModule.nix
    ./modules/base-image.nix
  ];

  partitionedAttrs.checks = "dev";
  partitionedAttrs.devShells = "dev";
  partitionedAttrs.formatter = "dev";

  partitions.dev = {
    extraInputsFlake = ../private;
    module =
      { inputs, ... }:
      {
        imports = [
          inputs.den.flakeModules.default
          inputs.treefmt-nix.flakeModule
          ./den
          ./modules/den.nix
          ./private.nix
        ];
      };
  };
}
