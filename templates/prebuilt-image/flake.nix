{
  description = "Minimal: boot a prebuilt NixOS qcow2 with Lima (no Linux builder needed on the host).";

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
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      flake.nixosConfigurations.work-vm = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.limavm.nixosModules.guest
          {
            lima = {
              enable = true;
              runner = {
                cpus = 4;
                memory = "4GiB";
                vmType = "vz";
              };
              # Prebuilt base image. URL or absolute path to a qcow2.
              # Setting this as a string skips building an image so no
              # Linux builder is required on the host.
              image = "https://example.com/nixos-base.qcow2";
            };
            users.users.root.password = "";
            system.stateVersion = "26.05";
          }
        ];
      };

      perSystem =
        { pkgs, ... }:
        let
          triple = inputs.limavm.lib.limavmPackages {
            inherit pkgs;
            name = "work-vm";
            nixosSystem = inputs.self.nixosConfigurations.work-vm;
          };
        in
        {
          packages = {
            # `nix run .#work-vm -- start` boots the VM from the prebuilt qcow2.
            work-vm = triple.start;
            work-vm-yaml = triple.yaml;
          };
        };
    };
}
