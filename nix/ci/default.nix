_: {
  flake.actions-nix.workflows =
    let
      baseSteps = [
        { uses = "actions/checkout@v6"; }
        {
          uses = "cachix/install-nix-action@v30";
          "with" = {
            nix_path = "nixpkgs=channel:nixos-unstable";
          };
        }
      ];
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
          schedule = [ { cron = "0 0 * * 0"; } ];
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
            baseSteps
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
