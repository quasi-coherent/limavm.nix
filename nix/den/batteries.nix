{ ... }:
{
  # Sugar over `host.lima.standalone`. Equivalent to writing the option
  # bag inline; useful when you want to share lima settings across
  # multiple hosts:
  #
  #   let
  #     baseVm = den.batteries.toLimaHost { cpus = 2; memory = "2GiB"; };
  #   in {
  #     den.hosts.aarch64-linux.vm-a.lima.standalone = baseVm;
  #     den.hosts.aarch64-linux.vm-b.lima.standalone = baseVm // { cpus = 4; };
  #   }
  #
  # If each host has bespoke lima settings, just write the option bag
  # inline; the battery adds nothing.
  den.batteries.toLimaHost = settings: { enable = true; } // settings;
}
