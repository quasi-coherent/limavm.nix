{
  description = "nixos host running a nixos guest";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.limavm.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      limavm,
      ...
    }:
    let
      hostSystem = "x86_64-linux";
      guestSystem = "x86_64-linux";

      workVm = nixpkgs.lib.nixosSystem {
        system = guestSystem;
        modules = [
          limavm.nixosModules.lima
          {
            lima = {
              enable = true;
              cpus = 4;
              memory = "4GiB";
              vmType = "qemu";
            };

            users.users.root.password = "";
            system.stateVersion = "26.05";
          }
        ];
      };
    in
    {
      nixosConfigurations.work-vm = workVm;

      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        system = hostSystem;
        modules = [
          limavm.nixosModules.host
          {
            system.stateVersion = "26.05";
            boot.loader.grub.device = "/dev/sda";
            fileSystems."/" = {
              device = "/dev/sda1";
              fsType = "ext4";
            };

            lima.vms.work-vm = {
              yaml = workVm.config.system.build.limaYaml;
              autoStart = true;
            };
          }
        ];
      };
    };
}
