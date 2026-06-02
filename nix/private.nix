{
  inputs,
  lib,
  config,
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

      # It's important to not write a check that needs to create the derivation
      # path `.drvPath` for anything that references the image `limaImage`.
      # That's because it'll try to download all of nixpkgs, which is crazy.
      checks = {
        lima-runner-eval = pkgs.writeText "lima-runner-eval" (
          if config.flake.packages.aarch64-linux ? lima-check-vm then
            "ok"
          else
            throw "mkLimactl did not emit flake.packages.aarch64-linux.lima-check-vm"
        );

        lima-plain-eval =
          let
            nixosCfg = inputs.nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = [
                self.nixosModules.lima
                {
                  lima.enable = true;
                  users.users.root.password = "";
                  system.stateVersion = "26.05";
                }
              ];
            };
          in
          pkgs.writeText "lima-plain-eval" (
            if nixosCfg.config.lima.enable then "ok" else throw "nixosModules.lima did not activate lima.enable"
          );
      };
    };
}
