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
      # The two host systems we're going to build nixOS to target.
      # You _can_ build and run `x86_64-linux` on darwin, but it's
      # more complicated.
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      # 1) The target: what the VM `nixos-rebuild`s after the first boot.
      #    This can be arbitrary.
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

      perSystem =
        let
          # 2) The deployment: Small package that just pins the base image and sets
          #    the bootstrap target.  Ultimately nothing (no image, at least) is
          #    built on the host system.
          deployment = inputs.nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              inputs.limavm.nixosModules.guest
              {
                lima = {
                  enable = true;
                  cpus = 4;
                  memory = "4GiB";
                  vmType = "vz";
                  image = "${inputs.limavm.packages.aarch64-linux.lima-base-image}/nixos.qcow2";
                  # Make the consumer's flake visible inside the VM so
                  # nixos-rebuild can reach it.
                  mounts = [
                    {
                      location = toString ./.;
                      writable = false;
                    }
                  ];
                  bootstrap = {
                    flake = toString ./.;
                    attr = "myvm";
                  };
                };
              }
            ];
          };
        in
        { pkgs, ... }:
        let
          trio = inputs.limavm.lib.mkGuestPackages {
            inherit pkgs;
            name = "myvm";
            settings = deployment.config.system.build.limaSettings;
            image = deployment.config.lima.image;
            inherit (deployment.config.lima) arch;
          };
        in
        {
          packages = {
            myvm = trio.start;
            myvm-yaml = trio.yaml;
          };
        };
    };
}
