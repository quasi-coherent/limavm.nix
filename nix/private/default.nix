{
  den,
  inputs,
  lib,
  ...
}:
{
  imports = [ ./actions.nix ];

  den.hosts.aarch64-linux.lima-check-vm = { };
  den.hosts.x86_64-linux.lima-check-vm = { };

  den.aspects.lima-check-vm.includes = [
    den.batteries.toLimaGuest
  ];

  den.aspects.lima-check-vm.lima = {
    lima.runner = {
      cpus = 2;
      memory = "2GiB";
      vmType = "vz";
    };
  };

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
    let
      guestSystem = if lib.hasPrefix "aarch" system then "aarch64-linux" else "x86_64-linux";
    in
    {
      treefmt = {
        projectRootFile = ".git/config";
        programs = {
          nixfmt = {
            enable = true;
            excludes = [ ".direnv" ];
          };
          typos.enable = true;
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
              curr=$(nix eval --raw --impure --file builtins.currentSystem)
              nix-fast-build --flake "$1" --systems "$curr" --no-link --skip-cached "''${@:2}"
            '';
          };
        in
        pkgs.mkShell {
          packages = [
            chkk
            fmtt
            pkgs.just
          ];
        };

      checks =
        let
          lima-lib = import ../lib { };
          denHost = den.hosts.${guestSystem}.lima-check-vm;
          denCfg = denHost.instantiate {
            inherit (denHost) system;
            modules = [
              (den.lib.aspects.resolve "nixos" (den.lib.resolveEntity "host" { host = denHost; }))
            ];
          };

          plainCfg = inputs.nixpkgs.lib.nixosSystem {
            system = guestSystem;
            modules = [
              ../lima.nix
              {
                lima.enable = true;
                users.users.root.password = "";
                system.stateVersion = "26.05";
              }
            ];
          };

          # Same as plainCfg but with a prebuilt image string set.
          prebuiltCfg = inputs.nixpkgs.lib.nixosSystem {
            system = guestSystem;
            modules = [
              ../lima.nix
              {
                lima.enable = true;
                lima.image = "https://example.invalid/base.qcow2";
                users.users.root.password = "";
                system.stateVersion = "26.05";
              }
            ];
          };

          mkWithImage =
            cfg: image:
            let
              location = if builtins.isString image then image else "${image}/nixos.qcow2";
              settings = cfg.config.system.build.limaSettings;
            in
            (pkgs.formats.yaml { }).generate "lima.yaml" (
              settings
              // {
                images = [
                  {
                    inherit (cfg.config.lima.runner) arch;
                    inherit location;
                  }
                ];
              }
            );
        in
        {
          # Image-less YAML, plain path.
          lima-plain-eval = plainCfg.config.system.build.evalSettings;

          # Image-less YAML, den path.
          lima-runner-eval = denCfg.config.system.build.evalSettings;

          # withImage applied with a prebuilt image.
          lima-plain-withImage-prebuilt = mkWithImage prebuiltCfg prebuiltCfg.config.lima.image;

          # Same but going through the den battery.
          lima-runner-withImage-prebuilt = mkWithImage denCfg "https://example.invalid/base.qcow2";

          # limavmPackages' start wrapper should build.
          lima-start-wrapper-prebuilt =
            (lima-lib.limavmPackages {
              pkgs = import inputs.nixpkgs {
                system = guestSystem;
              };
              name = "check-start";
              nixosSystem = prebuiltCfg;
            }).start;

          # Shouldn't break yaml.
          lima-postBoot-eval =
            let
              postBootCfg = inputs.nixpkgs.lib.nixosSystem {
                system = guestSystem;
                modules = [
                  ../lima.nix
                  {
                    lima.enable = true;
                    lima.image = "https://example.invalid/base.qcow2";
                    lima.guest.postBoot = [ "echo hi" ];
                    users.users.root.password = "";
                    system.stateVersion = "26.05";
                  }
                ];
              };
            in
            postBootCfg.config.system.build.evalSettings;
        };
    };
}
