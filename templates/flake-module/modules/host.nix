{ den, ... }:
{
  # A darwin host that runs vm1 + vm2 as launchd-managed Lima guests.
  # `laptop` gets vm1 and vm2 managed as launchd agents.
  den.hosts.aarch64-darwin.laptop = { };

  den.aspects.laptop.darwin = {
    system.stateVersion = 5;
  };

  den.aspects.laptop.includes = [
    (den.batteries.limaGuests [
      den.hosts.aarch64-linux.vm1
      den.hosts.aarch64-linux.vm2
    ])
  ];
}
