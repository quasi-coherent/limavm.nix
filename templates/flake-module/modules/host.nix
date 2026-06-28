{ den, ... }:
{
  den.hosts.aarch64-darwin.laptop = { };

  den.aspects.laptop.darwin = {
    system.stateVersion = 5;
  };

  # `limaGuests` makes `laptop` run vm1 and vm2 as launchd agents.
  #
  # Separately, this flake has the package outputs that can boot vm1 on its own
  # via `limaPackages`.
  den.aspects.laptop.includes = [
    (den.batteries.limaGuests [
      den.hosts.aarch64-linux.vm1
      den.hosts.aarch64-linux.vm2
    ])
  ];
}
