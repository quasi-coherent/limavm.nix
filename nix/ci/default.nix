{ ... }:
{
  flake.actions-nix.workflows =
    let
      checkout = {
        uses = "actions/checkout@v6";
      };

      installNix = {
        uses = "cachix/install-nix-action@v30";
        "with" = {
          nix_path = "nixpkgs=channel:nixos-unstable";
        };
      };

      cachixRead = [
        {
          uses = "cachix/cachix-action@v17";
          "with" = {
            name = "limavm-nix";
          };
        }
      ];
      cachixWrite = [
        {
          uses = "cachix/cachix-action@v17";
          "with" = {
            name = "limavm-nix";
            authToken = "\${{ secrets.CACHIX_AUTH_TOKEN }}";
          };
        }
      ];
      installNixKvm = {
        uses = "cachix/install-nix-action@v30";
        "with" = {
          nix_path = "nixpkgs=channel:nixos-unstable";
          extra_nix_config = "system-features = nixos-test benchmark big-parallel kvm";
        };
      };

      baseSteps = [
        checkout
        installNix
      ];

      baseBuildSteps = [
        checkout
        installNixKvm
      ];
    in
    {
      ".github/workflows/pr.yaml" = {
        on.pull_request.branches = [ "master" ];
        concurrency = {
          cancel-in-progress = true;
          group = "\${{ github.workflow }}-\${{ github.event.pull_request.number }}";
        };
        jobs.flake-check = {
          runs-on = "ubuntu-24.04";
          steps =
            baseSteps
            ++ cachixRead
            ++ [
              {
                name = "Run flake checks";
                run = "nix -Lv flake check";
              }
            ];
        };
      };

      ".github/workflows/templates-ci.yaml" = {
        on.push.branches = [ "master" ];
        jobs.templates-ci = {
          runs-on = "ubuntu-24.04";
          steps =
            baseSteps
            ++ cachixRead
            ++ [
              {
                name = "Run templates/ci flake checks";
                run = "nix -Lv flake check ./templates/ci";
              }
            ];
        };
      };

      ".github/workflows/base-image.yaml" = {
        on = {
          schedule = [ { cron = "0 0 * * *"; } ];
          workflow_dispatch = { };
        };
        jobs.build-base-image = {
          strategy.matrix.include = [
            {
              system = "x86_64-linux";
              runner = "ubuntu-24.04";
            }
            {
              system = "aarch64-linux";
              runner = "ubuntu-24.04-arm";
            }
          ];
          runs-on = "\${{ matrix.runner }}";
          steps =
            baseBuildSteps
            ++ cachixWrite
            ++ [
              {
                name = "Build lima-base-image";
                run = "nix -Lv build .#packages.\${{ matrix.system }}.lima-base-image";
              }
            ];
        };
      };
    };
}
