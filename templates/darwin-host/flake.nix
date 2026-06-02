{
  description = "nix-darwin host running a Lima nixosSystem guest (no den)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.darwin.url = "github:nix-community/nix-darwin";
  inputs.darwin.inputs.nixpkgs.follows = "nixpkgs";
  inputs.limavm.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      darwin,
      limavm,
      ...
    }:
    let
      hostSystem = "aarch64-darwin";
      guestSystem = "aarch64-linux";

      workVm = nixpkgs.lib.nixosSystem {
        system = guestSystem;
        modules = [
          limavm.nixosModules.lima
          {
            lima = {
              enable = true;
              cpus = 4;
              memory = "4GiB";
              vmType = "vz";
              rosetta.enabled = true;
              mounts = [
                {
                  location = "/Users";
                  writable = false;
                }
              ];
            };

            users.users.root.password = "";
            system.stateVersion = "26.05";
          }
        ];
      };
    in
    {
      nixosConfigurations.work-vm = workVm;

      darwinConfigurations.laptop = darwin.lib.darwinSystem {
        system = hostSystem;
        modules = [
          limavm.darwinModules.lima
          {
            system.stateVersion = 5;
            lima.vms.work-vm = {
              yaml = workVm.config.system.build.limaYaml;
              autoStart = true;
            };
          }
        ];
      };
    };
}
