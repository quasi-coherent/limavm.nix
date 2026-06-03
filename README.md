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

| Output                  | Runs guests via       |
| ----------------------- | --------------------- |
| `darwinModules.lima`    | `launchd.user.agents` |
| `nixosModules.lima`     | `systemd.services`    |
| `homeModules.lima`      | One or the other |

It also exposes a less conventional one, `limavm.flakeModules.den`; see [below](#den-integration).

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

### `mkGuestYaml`

Ad-hoc VMs can use `mkGuestYaml`:

```nix
yaml = limavm.lib.mkGuestYaml {
  inherit pkgs;
  system = "aarch64-linux";
  modules = [ { lima.enable = true; system.stateVersion = "26.05"; } ];
};
```

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

Then:

```console
$ nix run .#packages.aarch64-darwin.vm
```

starts the VM via `limactl start --name vm <generated lima.yaml>`.
