{ self, inputs, ... }:
{
  systems = [
    "aarch64-darwin"
    "x86_64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  flake = {
    lib = import ./lib { inherit (inputs.nixpkgs) lib; };

    darwinModules = {
      default = self.darwinModules.lima;
      lima.imports = [
        ./modules/darwin.nix
      ];
    };

    flakeModules = {
      den.imports = [
        ./den
        ./modules/den.nix
      ];
      home-manager.imports = [ ./modules/home.nix ];
    };

    nixosModules = {
      default = self.nixosModules.lima;
      lima.imports = [ ./modules/nixos.nix ];
      guest.imports = [
        ./options.nix
        ./lima.nix
      ];
    };

    templates = {
      flake-module = {
        path = ../templates/flake-module;
        description = "den hosts/aspects with `toLima` battery.";
      };
      nixos-host = {
        path = ../templates/nixos-host;
        description = "NixOS host + nixosSystem guest.";
      };
      darwin-host = {
        path = ../templates/darwin-host;
        description = "nix-darwin host + nixosSystem guest.";
      };
      ci = {
        path = ../templates/ci;
        description = "Smoke test, not intended for use.";
      };
      prebuilt-image = {
        path = ../templates/prebuilt-image;
        description = "Pre-built qcow2 disk image from URL/path with Lima.";
      };
      bootstrap = {
        path = ../templates/bootstrap;
        description = "Pre-built image with `nixosSystem` activated post-boot.";
      };
    };
  };
}
