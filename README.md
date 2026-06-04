# limavm.nix

A flake for running NixOS as a [Lima](https://lima-vm.io/)-managed VM on macOS
or Linux hosts.

See the [templates](./templates) directory for examples you can run.

## Usage

```nix
inputs.limavm.url = "github:quasi-coherent/limavm.nix";
inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";
```

The flake exposes the conventional modules:

| Output                      | Runs guests via      |
| --------------------------- | -------------------- |
| `darwinModules.lima` | `launchd.user.agents` |
| `nixosModules.lima` | `systemd.services` |
| `flakeModules.home-manager` | One or the other |
| `flakeModules.den` | See [below](#den-integration) |

### Declaring a VM

You can declare a `vms.<name>` entry from a pre-built `lima.yaml`:

```nix
services.limavm-nix.vms.work.yaml = ./lima.yaml; # or some store path
```

The NixOS guest can be defined inline too:

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

### Ad-hoc guests via `evalGuest`

For one-off VMs, evaluate a guest config and grab its rendered `lima.yaml`:

```nix
yaml = (limavm.lib.evalGuest pkgs {
  system = "aarch64-linux";
  modules = [ { lima.enable = true; system.stateVersion = "26.05"; } ];
}).config.system.build.limaYaml;
```

`limavm.lib.evalGuest` returns a `nixosSystem` and here the `system.build.limaYaml`
attribute is the assembled YAML config for `limactl`, including the VM image tag+sha.

Evaluating this requires building the image, which is sometimes very much not what you
want.  To fetch the YAML file minus the image tag, use `system.build.evalYaml` instead.
Of course, it is not valid to give this to `limactl`.

## den integration

If you use the [den](https://den.denful.dev) framework, `lima` is a den class extending
`host` that two batteries are exposed for:

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
