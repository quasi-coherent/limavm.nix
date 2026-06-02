{ den, ... }:
{
  # `aarch64-linux` is the *guest*. `runnerSystems` here narrows the
  # default (`${arch}-darwin` + `${arch}-linux`) to just the darwin
  # wrapper — appropriate since the lima settings below (rosetta,
  # `/Users` mount) only make sense on a macOS host.
  den.hosts.aarch64-linux.dev-vm.lima.standalone = den.batteries.toLimaHost {
    cpus = 4;
    memory = "4GiB";
    vmType = "vz";
    rosetta.enabled = true;
    mounts = [
      {
        location = "/Users";
        writable = false;
      }
    ];
    runnerSystems = [ "aarch64-darwin" ];
  };

  den.aspects.dev-vm.includes = [
    den.aspects.base
    den.aspects.dev-tools
    den.aspects.nginx
  ];
}
