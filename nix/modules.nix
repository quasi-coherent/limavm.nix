{ self, ... }:
{
  systems = [
    "aarch64-darwin"
    "x86_64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  flake = {
    lib = import ./lib;

    flakeModules = {
      default = self.flakeModules.den;
      den = {
        imports = [
          ./den
          self.lib.den.mkLimactl
        ];
      };
    };

    nixosModules = {
      default = self.nixosModules.lima;
      lima = {
        imports = [
          ./options.nix
          ./lima-init.nix
        ];
      };
      lima-host = {
        imports = [
          ./options-host.nix
          self.lib.nixosHost
        ];
      };
    };

    darwinModules = {
      default = self.darwinModules.lima;
      lima = {
        imports = [
          ./options-host.nix
          self.lib.darwinHost
        ];
      };
    };

    templates = {
      guest = {
        path = ../templates/guest;
        description = "Single Lima guest as a runnable flake package (`nix run`).";
      };
      aspects = {
        path = ../templates/aspects;
        description = "Lima guest composed from multiple den aspects.";
      };
      darwin-host = {
        path = ../templates/darwin-host;
        description = "Pure nix-darwin host + nixosSystem guest, no den, wired via darwinModules.lima.";
      };
    };
  };
}
