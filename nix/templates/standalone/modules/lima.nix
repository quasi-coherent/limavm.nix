{ inputs, ... }:
{
  den.hosts.aarch64-linux.runnable-lima = {
    intoAttr = [
      "limaGuests"
      "runnable-lima"
    ];
  };

  den.aspects.runnable-lima = {
    nixos = {
      imports = [ inputs.limavm.nixosModules.limavm ];
      users.users.root.password = "";
      system.stateVersion = "24.11";
    };

    lima = {
      cpus = 2;
      memory = "2GiB";
      vmType = "vz";
      rosetta.enabled = true;
      mounts = [
        {
          location = "/Users";
          writable = false;
        }
      ];
    };
  };
}
