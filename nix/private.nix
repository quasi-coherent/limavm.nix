{
  inputs,
  lib,
  self,
  den,
  ...
}:
{
  # With den.
  den.hosts.aarch64-linux.lima-check-vm = { };

  den.aspects.lima-check-vm.includes = [
    (den.batteries.toLima {
      cpus = 2;
      memory = "2GiB";
      vmType = "vz";
    })
  ];

  den.aspects.lima-check-vm.nixos = {
    users.users.root.password = "";
    system.stateVersion = "26.05";
  };

  perSystem =
    {
      pkgs,
      self',
      system,
      ...
    }:
    {
      treefmt = {
        projectRootFile = ".git/config";
        programs = {
          nixfmt = {
            enable = true;
            excludes = [ ".direnv" ];
          };
          deadnix.enable = true;
        };
      };

      devShells.default =
        let
          fmtt = pkgs.writeShellApplication {
            name = "fmtt";
            text = ''${lib.getExe self'.formatter} "$@"'';
          };
          chkk = pkgs.writeShellApplication {
            name = "chkk";
            runtimeInputs = with pkgs; [
              nix
              nix-fast-build
            ];
            text = ''
              nix-fast-build --flake ".#checks.${system}" --no-link --skip-cached "$@"
            '';
          };
        in
        pkgs.mkShell {
          packages = [
            fmtt
            chkk
          ];
        };

      checks = {
        # It's important to not write a check that needs to create the derivation
        # path `.drvPath` for anything that references the image `limaImage`.
        # That's because it'll try to download all of nixpkgs, which is crazy.
        #
        # This creates lima.yaml without the boot image hash.
        lima-runner-eval =
          let
            nixosCfg = inputs.nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = [
                ./options.nix
                ./lima.nix
                {
                  lima = {
                    enable = true;
                    cpus = 2;
                    memory = "2GiB";
                    vmType = "vz";
                    runner = true;
                  };
                  users.users.root.password = "";
                  system.stateVersion = "26.05";
                }
              ];
            };
          in
          self.lib.evalLimaYaml {
            inherit pkgs;
            config = nixosCfg.config;
          };

        lima-plain-eval =
          let
            nixosCfg = inputs.nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = [
                ./options.nix
                ./lima.nix
                {
                  lima.enable = true;
                  users.users.root.password = "";
                  system.stateVersion = "26.05";
                }
              ];
            };
          in
          self.lib.evalLimaYaml {
            inherit pkgs;
            config = nixosCfg.config;
          };
      };
    };
}
