{ ... }:
{
  den.hosts.aarch64-linux.my-nixos.lima.standalone = {
    enable = true;
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

  den.aspects.my-nixos.nixos = {
    users.users.root.password = "";
    system.stateVersion = "26.05";
  };
}
