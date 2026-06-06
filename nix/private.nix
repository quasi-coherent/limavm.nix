{
  inputs,
  lib,
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

      checks =
        # It's important to not write a check that needs to create the derivation
        # path `.drvPath` for anything that references the image `limaImage`.
        # That's because it'll try to download all of nixpkgs, which is crazy.
        # The checks below stay on cheap paths: evalYaml (image-less) and
        # withImage with a prebuilt string ref (so no image build is triggered).
        let
          lima-lib = import ./lib { inherit lib; };

          # Cheap plain NixOS guest eval (no den).
          plainCfg = inputs.nixpkgs.lib.nixosSystem {
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

          # Same as plainCfg but with a prebuilt image string set — exercises
          # the conditional `limaImage` (it should NOT be defined here) and
          # the withImage code path.
          prebuiltCfg = inputs.nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              ./options.nix
              ./lima.nix
              {
                lima.enable = true;
                lima.image = "https://example.invalid/base.qcow2";
                users.users.root.password = "";
                system.stateVersion = "26.05";
              }
            ];
          };

          # Den path: same shape but routed through the toLima battery.
          denHost = den.hosts.aarch64-linux.lima-check-vm;
          denCfg = denHost.instantiate {
            inherit (denHost) system;
            modules = [
              (den.lib.aspects.resolve "nixos" (den.lib.resolveEntity "host" { host = denHost; }))
            ];
          };

          mkWithImage =
            cfg: image:
            lima-lib.withImage {
              inherit pkgs image;
              inherit (cfg.config.lima) arch;
            } cfg.config.system.build.limaSettings;
        in
        {
          # Image-less YAML, plain path.
          lima-plain-eval = plainCfg.config.system.build.evalYaml;

          # Image-less YAML, den path.
          lima-runner-eval = denCfg.config.system.build.evalYaml;

          # withImage applied with a prebuilt string ref. Does NOT trigger
          # any image build because the ref is a literal string.
          lima-plain-withImage-prebuilt = mkWithImage prebuiltCfg prebuiltCfg.config.lima.image;

          # Same but going through the den battery, with a string image
          # override supplied at withImage call time (the den config itself
          # doesn't set lima.image).
          lima-runner-withImage-prebuilt = mkWithImage denCfg "https://example.invalid/base.qcow2";

          # Smoke check that mkGuestPackages's start wrapper builds.
          lima-start-wrapper-prebuilt =
            (lima-lib.mkGuestPackages {
              inherit pkgs;
              name = "check-start";
              settings = prebuiltCfg.config.system.build.limaSettings;
              image = prebuiltCfg.config.lima.image;
              inherit (prebuiltCfg.config.lima) arch;
            }).start;

          # Bootstrap path: setting `lima.bootstrap.flake` should emit a
          # provision script that writes /etc/lima-bootstrap/env. We build
          # the evalYaml of a config that sets both image (string) and
          # bootstrap.flake — confirms option resolution and provision wiring
          # render cleanly without triggering an image build.
          lima-bootstrap-eval =
            let
              bootstrapCfg = inputs.nixpkgs.lib.nixosSystem {
                system = "aarch64-linux";
                modules = [
                  ./options.nix
                  ./lima.nix
                  {
                    lima.enable = true;
                    lima.image = "https://example.invalid/base.qcow2";
                    lima.bootstrap.flake = "/fake/path/to/flake";
                    lima.bootstrap.attr = "myvm";
                    users.users.root.password = "";
                    system.stateVersion = "26.05";
                  }
                ];
              };
            in
            bootstrapCfg.config.system.build.evalYaml;

          # postBoot option: setting it shouldn't break evalYaml rendering.
          lima-postBoot-eval =
            let
              postBootCfg = inputs.nixpkgs.lib.nixosSystem {
                system = "aarch64-linux";
                modules = [
                  ./options.nix
                  ./lima.nix
                  {
                    lima.enable = true;
                    lima.image = "https://example.invalid/base.qcow2";
                    lima.postBoot = [ "echo hi" ];
                    users.users.root.password = "";
                    system.stateVersion = "26.05";
                  }
                ];
              };
            in
            postBootCfg.config.system.build.evalYaml;
        };
    };
}
