# limavm.nix

A flake to build and run NixOS as a Lima-managed VM on MacOS or Linux hosts.

See the [templates](./nix/templates) directory for examples.

## Usage

Add to your flake.nix:

```nix
inputs.limavm-nix.url = "github:quasi-coherent/limavm.nix";
inputs.limavm-nix.inputs.nixpkgs = "nixpkgs";
```

`limavm-nix` exposes the conventional flake modules:

* **Darwin host**: `darwinModules` adds options to run `nixosSystem`s as launchd
  agents.  See the example [template](./templates/darwin-host).
* **NixOS host**: Pretty much the same example except you import `nixosModules`
  and get systemd services instead.

### `den`

This also adds an extension of the [den] framework by defining a class that
represents a Lima VM.  This gets wired to den's resolution pipeline in the
above two ways, via a systemd service or launchd agent.  The `limaGuests`
battery is sugar for adding one or more VMs:

```nix
{ den, ... }:

den.aspects.my-darwin-host.includes = [
  (den.batteries.limaGuests [
    den.aspects.my-nixos-vm1
    den.aspects.my-nixos-vm2
    den.aspects.my-nixos-vm3
  ])
];
```

Additionally, you can write a more intrinsic definition and get a flake package
output from it:

```nix
den.aspects.vm.includes = [
  den.aspects.editor
  den.aspects.secrets
  den.aspects.cli-tools
  (den.batteries.toLima {
    cpus = 4;
    memory = "8GiB";
    mounts = [
      {
        location = "~/.config/sops/age/keys.txt";
        writeable = false;
      }
    ];
    vmType = "vz";
  })
];
```

Then

```console
> $ nix run .#packages.aarch64-darwin.*
```

starts the VM as `limactl start --name [HOST] [YAML]`.

### TODO

Add other `limactl` pre-configured commands to the wrapper.

[den]: https://den.denful.dev
[eg1]: ./templates/guests
[eg2]: ./templates/aspects
