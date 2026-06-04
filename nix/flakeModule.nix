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

    darwinModules = {
      default = self.darwinModules.lima;
      lima = {
        imports = [
          ./modules/darwin.nix
        ];
      };
    };

    flakeModules = {
      den = {
        imports = [
          ./den
          ./options.nix
          ./modules/den.nix
        ];
      };
      home-manager = {
        imports = [ ./modules/home.nix ];
      };
    };

    nixosModules = {
      default = self.nixosModules.lima;
      lima = {
        imports = [
          ./modules/nixos.nix
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
