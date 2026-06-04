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
          inputs.limavm.nixosModules.lima
          {
            lima = {
              enable = true;
              cpus = 2;
              memory = "2GiB";
              vmType = "qemu";
            };
            users.users.root.password = "";
            system.stateVersion = "26.05";
          }
        ];
      };

      perSystem =
        { self', ... }:
        let
          guest = inputs.self.nixosConfigurations.ci-guest;
        in
        {
          # Expose the heavy artifacts so CI can `nix build .#image` etc.
          packages = {
            image = guest.config.system.build.limaImage;
            lima-yaml = guest.config.system.build.limaYaml;
          };

          # And as a check so `nix flake check` in CI exercises the full pipeline.
          # Locally users should `nix flake check` in the *library* repo, which
          # stays fast — this check is intentionally expensive.
          checks = {
            inherit (self'.packages) image lima-yaml;
          };
        };
    };
}
