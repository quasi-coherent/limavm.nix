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
          ./lima.nix
        ];
      };
      host = {
        imports = [
          ./host.nix
          self.lib.nixosHost
        ];
      };
    };

    darwinModules = {
      default = self.darwinModules.host;
      host = {
        imports = [
          ./host.nix
          self.lib.darwinHost
        ];
      };
    };

    templates = {
      flake-module = {
        path = ../templates/flake-module;
        description = "Dendritic flake: den hosts/aspects with `toLima` + `limaGuests` batteries.";
      };
      nixos-host = {
        path = ../templates/nixos-host;
        description = "Pure NixOS host + nixosSystem guest, no den, wired via nixosModules.host.";
      };
      darwin-host = {
        path = ../templates/darwin-host;
        description = "Pure nix-darwin host + nixosSystem guest, no den, wired via darwinModules.host.";
      };
    };
  };
}
