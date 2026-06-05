<h2 align="center">liamvm.nix</h2>

A flake for building and/or running [Lima]-managed VMs on macOS or Linux hosts.

## Usage

```nix
inputs.limavm.url = "github:quasi-coherent/limavm.nix";
inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";
```

The flake exposes conventional modules:

| Output                      | Runs guests via      |
| --------------------------- | -------------------- |
| `darwinModules.lima` | `launchd.user.agents` |
| `nixosModules.lima` | `systemd.services` |
| `flakeModules.home-manager` | One or the other |
| `flakeModules.den` | See [below](#den-integration) |


Each offer different ways to get a Lima VM that have different requirements for different
host systems.

### Using a pre-built image

You can rely on an existing disk image and reference it in a `lima.yaml` that follows the format
that a "normal" use of Lima with a [template](https://lima-vm.io/docs/templates/) would point to.
This `lima.yaml` can be used to declare a `services.limavm-nix.vms` entry:

```nix
services.limavm-nix.vms.work.yaml = ./lima.yaml; # or some store path
```

This would create a `launchd` agent or `systemd` user service from VM defined in `lima.yaml`.

Some `lima.yaml` examples can be found in the [templates][lima-yaml] provided by Lima.

### Building from a `nixosSystem`

It's also possible to create a Lima VM guest by building the disk image from a custom `nixosSystem`
defined inline:

```nix
# darwin host running a NixOS guest
darwinConfigurations.laptop = darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    limavm.darwinModules.lima
    {
      services.limavm-nix = {
        enable = true;
        vms.work = {
          autoStart = true;
          guest = {
            system = "aarch64-linux";
            modules = [{
              lima = {
                enable = true;
                cpus = 4;
                memory = "4GiB";
                vmType = "vz";
                rosetta.enabled = true;
                mounts = [ { location = "/Users"; writable = false; } ];
              };
              users.users.root.password = "";
              system.stateVersion = "26.05";
            }];
          };
        };
      };
    }
  ];
};
```

This merges `vms.*.guest.modules` into a `nixosSystem`, which is used to build a Lima VM, and in this case,
a `launchd` agent is created for `darwinConfigurations.laptop` that starts and runs the VM.

#### MacOS hosts

For a MacOS host, this disk image is built on `aarch64-linux`/`x86_64-linux` and cannot be produced natively.
Users of `nix-darwin` can enable the `nix.linux-builder` [option][nix-linux-builder] to be able to build nixOS VM images.
DeterminateNix users can use the native Linux [builder][detsys-builder], which is probably the best available option.

### den integration

If you use the [den](https://den.denful.dev) framework, `lima` is a den class extending `host` that two
batteries are exposed for:

```nix
# Run a list of den hosts as Lima guests on the including host.
den.aspects.my-darwin-host.includes = [
  (den.batteries.limaGuests [
    den.hosts.my-nixos-vm1
    den.hosts.my-nixos-vm2
  ])
];

# Expose the including host as a runnable Lima guest at
# `flake.packages.<sys>.<host>`.
den.aspects.vm.includes = [
  den.aspects.editor
  den.aspects.cli-tools
  (den.batteries.toLima {
    cpus = 4;
    memory = "8GiB";
    vmType = "vz";
  })
];
```

### Ad-hoc guests via `evalGuest`

For one-off VMs, evaluate a guest config and grab its rendered `lima.yaml`:

```nix
yaml = (limavm.lib.evalGuest pkgs {
  system = "aarch64-linux";
  modules = [ { lima.enable = true; system.stateVersion = "26.05"; } ];
}).config.system.build.limaYaml;
```

`limavm.lib.evalGuest` returns a `nixosSystem` and here the `system.build.limaYaml` attribute is the assembled `lima.yaml`
config, including the VM image tag+sha.

Evaluating this requires building the image, which is sometimes very much not what you want.  To fetch the YAML file minus
the image tag, use `system.build.evalYaml` instead. Of course, it is not valid to give this to `limactl`.

## TODO

1. Build a base image and expose it in this flake.  Distribute it via cachix.
   - This is for MacOS users to avoid the linux-builder song and dance.
2. Add a module and option `lima.baseImage` option to specify a pre-built image alongside the other `lima` options.
   Then:
   - This flake would provide the wiring to _first_ launch the VM and _then_ deploy a `nixosSystem` inside the VM.
   - This way you can get a custom nixOS system but without having to build it from scratch yourself.

[Lima]: https://lima-vm.io/
[lima-yaml]: https://github.com/lima-vm/lima/tree/master/templates
[nix-linux-builder]: https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-nix.linux-builder.enable
[detsys-builder]: https://docs.determinate.systems/determinate-nix/linux-builder/
