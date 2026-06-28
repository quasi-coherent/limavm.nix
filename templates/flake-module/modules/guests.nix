{ den, ... }:
{
  # Two guest hosts. Each is its own `den.hosts.<system>.<name>`.
  den.hosts.aarch64-linux.vm1 = { };
  den.hosts.aarch64-linux.vm2 = { };

  # `toLimaGuest` publishes vm1 as a flake package so you can start it by hand:
  # `nix run .#vm1` (plus `.#vm1-yaml` and `.#vm1-image`).  This is in addition
  # to it being suitable to include as a guest service on a separate host.
  den.aspects.vm1.includes = [
    den.aspects.base
    den.aspects.dev-tools
    den.batteries.toLimaGuest
  ];

  # Uses the `lima` den class to add configuration of the lima options tree.
  den.aspects.vm1.lima = {
    lima.runner = {
      cpus = 4;
      memory = "8GiB";
    };
  };

  # Same way to configure the VM, but this does not emit the package outputs to
  # be able to launch vm2 on its own, independently of a separate host.  This
  # can only by included as a guest (a systemd or launchd service) of another
  # host.
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
