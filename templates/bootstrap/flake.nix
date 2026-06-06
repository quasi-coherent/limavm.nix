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
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
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

      # 2) The deployment: Small package that just pins the base image and sets
      #    the bootstrap target.  Ultimately nothing (no image, at least) is
      #    built on the host system.
      perSystem =
        { pkgs, system, ... }:
        let
          baseSystem = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64-linux" else "x86_64-linux";
          baseImage = inputs.limavm.packages.${baseSystem}.lima-base-image;

          deployment = inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              inputs.limavm.nixosModules.guest
              {
                lima = {
                  enable = true;
                  cpus = 4;
                  memory = "4GiB";
                  vmType = "vz";
                  image = "${baseImage}/nixos.qcow2";
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
