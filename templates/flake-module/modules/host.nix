{ den, ... }:
{
  den.hosts.aarch64-darwin.laptop = { };

  den.aspects.laptop.darwin = {
    system.stateVersion = 5;
  };

  # `laptop` gets vm1 and vm2 managed as launchd agents when declared on the
  # den.hosts.aarch64-darwin aspect.
  den.aspects.laptop.includes = [
    (den.batteries.limaGuests [
      den.hosts.aarch64-linux.vm1
      den.hosts.aarch64-linux.vm2
    ])
  ];
}
