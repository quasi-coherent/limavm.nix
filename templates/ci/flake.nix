{
  description = "Full-build smoke test for limavm.nix — builds the qcow2 image and lima.yaml. Run in CI, not locally.";
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
        "x86_64-darwin"
        "x86_64-linux"
      ];

      flake.nixosConfigurations.ci-guest = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          inputs.limavm.nixosModules.guest
          {
            lima = {
              enable = true;
              runner = {
                cpus = 2;
                memory = "2GiB";
                vmType = "qemu";
              };
            };
            users.users.root.password = "";
            system.stateVersion = "26.05";
          }
        ];
      };

      perSystem =
        {
          pkgs,
          self',
          ...
        }:
        let
          guest = inputs.self.nixosConfigurations.ci-guest;
          image = guest.config.system.build.limaImage;

          lima-yaml =
            let
              settings = guest.config.system.build.limaSettings;
              location = "${image}/nixos.qcow2";
            in
            (pkgs.formats.yaml { }).generate "lima.yaml" (
              settings
              // {
                images = [
                  {
                    inherit (guest.config.lima.runner) arch;
                    inherit location;
                  }
                ];
              }
            );
        in
        {
          packages = {
            inherit image lima-yaml;
          };

          checks = {
            inherit (self'.packages) image lima-yaml;
          };
        };
    };
}
