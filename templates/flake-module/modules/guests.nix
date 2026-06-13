{ den, ... }:
{
  # Two guest hosts. Each is its own `den.hosts.<system>.<name>`.
  den.hosts.aarch64-linux.vm1 = { };
  den.hosts.aarch64-linux.vm2 = { };

  # `toLimaGuest` makes vm1 runnable via `nix run`. It reads `lima`-class
  # content from this aspect (and any others it includes), so the runner
  # settings live as `den.aspects.vm1.lima` content rather than as a battery
  # argument.
  den.aspects.vm1.includes = [
    den.aspects.base
    den.aspects.dev-tools
    den.batteries.toLimaGuest
  ];

  den.aspects.vm2.lima = {
    lima.runner = {
      cpus = 2;
      memory = "2GiB";
      vmType = "vz";
      rosetta.isEnabled = true;
    };
    # Setting `lima.image = "https://.../base.qcow2"` here would skip the
    # qcow2 build entirely (no Linux builder required).
  };

  den.aspects.vm2.includes = [
    den.aspects.base
    den.aspects.nginx
  ];
}
