{ den, ... }:
{
  den.hosts.aarch64-darwin.laptop.lima.guests = [
    den.hosts.aarch64-linux.work-vm
  ];

  den.hosts.aarch64-linux.work-vm = {
    intoAttr = [ ];
  };

  den.aspects.laptop = {
    darwin = {
      system.stateVersion = 5;
    };
  };

  den.aspects.work-vm = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.git ];
        system.stateVersion = "24.11";
      };

    lima = {
      cpus = 4;
      memory = "4GiB";
      vmType = "vz";
      rosetta.enabled = true;
      mounts = [
        {
          location = "/Users/yourname";
          writable = true;
        }
      ];
      portForwards = [
        {
          guestPort = 8080;
          hostPort = 18080;
        }
      ];
    };
  };
}
