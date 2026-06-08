{
  description = "Boot limavm's base image and nixos-rebuild into another nixosSystem on first boot.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.limavm.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      # The target nixosSystem the VM rebuilds into on first boot.
      # Must import limavm.nixosModules.guest so that it's a valid lima-bootable
      # system on its own.
      flake.nixosConfigurations.myvm = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.limavm.nixosModules.guest
          (
            { pkgs, ... }:
            {
              lima.enable = true;
              users.users.root.password = "";
              system.stateVersion = "26.05";

              environment.systemPackages = with pkgs; [
                git
                ripgrep
              ];
            }
          )
        ];
      };

      # `mkBaseImageRunner` is a wrapper around `limactl` for the base lima image
      # that appends `nixos-rebuild switch --flake .#myvm`.
      perSystem =
        { pkgs, ... }:
        let
          triple = inputs.limavm.lib.mkBaseImageRunner {
            inherit pkgs;
            name = "myvm";
            baseImage = "${inputs.limavm.packages.aarch64-linux.lima-base-image}/nixos.qcow2";
            flake = toString ./.;
            attr = "myvm";
            settings = {
              cpus = 4;
              memory = "4GiB";
              vmType = "vz";
              mounts = [
                {
                  location = toString ./.;
                  writable = false;
                }
              ];
            };
          };
        in
        {
          packages = {
            myvm = triple.start;
            myvm-yaml = triple.yaml;
          };
        };
    };
}
