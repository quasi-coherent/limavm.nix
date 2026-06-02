{ den, ... }:
{
  # `aarch64-linux` is the *guest* system. `mkLimactl` emits the
  # runner under both `aarch64-darwin` and `aarch64-linux` by default
  # (`limactl` runs on the host, not the guest), so `nix run .#my-nixos`
  # works from either. Narrow with `runnerSystems = [ "aarch64-darwin" ];`.
  den.hosts.aarch64-linux.my-nixos.lima.standalone = den.batteries.toLimaHost {
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
