{ den, ... }:
{
  imports = [ ./zim.nix ];

  den.hosts.aarch64-linux.zimHost = { };

  den.aspects.zimHost = {
    includes = [
      den.aspects.zim
      den.batteries.limaPackages
    ];

    limaGuest = {
      lima.runner = {
        cpus = 2;
        memory = "4GiB";
        disk = "20GiB";
        portForwards = [
          {
            guestPort = 5555;
            hostPort = 10555;
          }
        ];
      };
    };

    nixos = { pkgs, ... }: {
      system.stateVersion = "26.05";

      users.users.root.password = "";
      users.users.dev = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        password = "";
      };

      environment.systemPackages = with pkgs; [
        emacs30
        fd
        jq
        git
        ripgrep
      ];
    };
  };
}
