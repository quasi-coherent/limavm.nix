{ den, ... }:
{
  # Two guest hosts. Each is its own `den.hosts.<system>.<name>`.
  den.hosts.aarch64-linux.vm1 = { };
  den.hosts.aarch64-linux.vm2 = { };

  # `toLima` makes vm1 runnable via `nix run`.
  den.aspects.vm1.includes = [
    den.aspects.base
    den.aspects.dev-tools
    (den.batteries.toLima {
      cpus = 2;
      memory = "2GiB";
      vmType = "vz";
      rosetta.enabled = true;
    })
  ];

  den.aspects.vm2.includes = [
    den.aspects.base
    den.aspects.nginx
  ];
}
