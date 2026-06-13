{
  description = "nix-darwin host running a nixos guest";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.darwin.url = "github:nix-community/nix-darwin";
  inputs.darwin.inputs.nixpkgs.follows = "nixpkgs";
  inputs.limavm.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      darwin,
      limavm,
      ...
    }:
    {
      darwinConfigurations.laptop = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          limavm.darwinModules.lima
          {
            system.stateVersion = 5;
            services.limavm-nix = {
              enable = true;
              # `user` supplies the default for `limaHomeDir`
              # (`${config.users.users.<user>.home}/.lima`). Leave null to let
              # `limactl` pick its own per-OS default at runtime.
              user = "alice";
              vms.work-vm = {
                autoStart = true;
                # Optional: boot a prebuilt qcow2 (URL or local path) instead
                # of building one, e.g.,
                #   image = "https://example.com/nixos-base.qcow2";
                # Overrides the inline guest's `lima.image`.

                # Without this, the inline Lima guest has to be built on the
                # _darwin_ host, which is not generally possible unless it has
                # some tooling already in the environment, e.g., nix-darwin's
                # nix.linux-builder.
                guest = {
                  modules = [
                    {
                      lima = {
                        enable = true;
                        runner = {
                          cpus = 4;
                          memory = "4GiB";
                          vmType = "vz";
                          rosetta.isEnabled = true;
                          mounts = [
                            {
                              location = "/Users";
                              writable = false;
                            }
                          ];
                        };
                      };
                      users.users.root.password = "";
                      system.stateVersion = "26.05";
                    }
                  ];
                };
              };
            };
          }
        ];
      };
    };
}
