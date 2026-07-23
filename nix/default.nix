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
  partitions.dev.extraInputsFlake = ../private;
  partitions.dev.module =
    { inputs, self, ... }:
    {
      imports = [
        inputs.den.flakeModules.default
        inputs.treefmt-nix.flakeModule
        self.flakeModules.den
        ./private
      ];
    };
}
