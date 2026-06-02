# limavm.nix

A flake to build and run NixOS as a Lima-managed VM on MacOS or Linux hosts.

## Usage

Add to your flake.nix:

```nix
inputs.limavm-nix.url = "github:quasi-coherent/limavm.nix";
inputs.limavm-nix.inputs.nixpkgs = "nixpkgs";
```

`limavm-nix` exposes the conventional flake modules:

* *Darwin host*: `darwinModules` adds options to run `nixosSystem`s as launchd
  agents.  See the example [template](./templates/darwin-host).
* *NixOS host*: Pretty much the same example except you would import the module
  `nixosModules` instead, and the VMs will be systemd services instead.

### `den`

This also sets up some wiring to use with the [den] framework:

```nix
# base.nix -- default OS settings aspect
den.aspects.base-nixos = {
  nixos =
  { pkgs, ... }:
  {
    environment.systemPackages = with pkgs; [
      cowsay
      emacs30
      fd
      git
      ripgrep
    ];
  };
};

# host.nix
{ inputs, ... }:
{
  imports = [ inputs.limavm-nix.flakeModules.den ];

  den.aspects.my-nixos.includes = [
    den.aspects.base-nixos
    (den.batteries.toLimaHost {
      cpus = 4;
      memory = "4GiB";
      vmType = "qemu";
      mounts = [
        {
          location = "/Users/darwin-user/.config/sops/age/keys.txt";
          writable = false;
        }
      ];
    })
  ];

  den.hosts.aarch64-linux.my-nixos = { };
}
```

The battery `toLimaHost` has the effect of emitting a flake package output
`my-nixos`.  This package will build a Lima image and config from the provided
options and exposes a `limactl` wrapper that is pre-configured to boot a VM
from the constructed image and settings.

Packages are emitted that target both `aarch64-darwin` and `aarch64-linux` in
this example, which is assuming that the host is `aarch64-darwin`.  In other
words, the guest VM is set on _its own_ host system `aarch64-linux`, but the
command

```console
> $ nix run .#packages.aarch64-darwin.my-nixos
```

is called from the main Darwin host.

[den]: https://den.denful.dev
