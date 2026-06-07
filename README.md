<h2 align="center">limavm.nix</h2>

A flake for building and running [Lima]-managed VMs on macOS or Linux hosts.

## Usage

```nix
inputs.limavm.url = "github:quasi-coherent/limavm.nix";
inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

# To get the cached Lima base image:
nixConfig = {
  extra-substituters = [ "https://limavm-nix.cachix.org" ];
  extra-trusted-public-keys = [
    "limavm-nix.cachix.org-1:3tRE+cBpLSZlcb6Mjgxjif+QCG6mJXuDyjyMHHXgx8I="
  ];
};
```

The flake exposes the conventional modules:

Import | Runs guests via
:---: | :---
`darwinModules` | `launchd.user.agents`
`nixosModules` | `systemd.services`
`nixosModules.guest` | `limavm.lib.mkGuestPackages`
`flakeModules.home-manager` | `launchd` or `systemd`
`flakeModules.den` | `packages.{sys}.{vm}-*`, see [below](#den-integration)

It also exposes `limavm-nix.packages.{sys}.lima-base-image` for
aarch/x84 linux `sys`.

This is a pre-built Lima disk image that a minimal nixOS VM can boot
from.  It's available from the `limavm-nix` public cache hosted on
cachix.  For a darwin host you have to use this cache to avoid having
to build the image in cases where you're not specifying a URL or local
qcow2 path for the base image, which would otherwise require extra
setup.

Each of the modules have different uses and requirements for
different host systems.

### NixOS host and NixOS guest

One or more `nixosSystem`s can be declared in a `services.limavm-nix`
configuration.  These ultimately become systemd services in the
`nixosSystem` that set the option.

See the [template](./templates/nixos-host) example.

### Darwin host and NixOS guest

In an identical fashion, one or more `nixosSystem`s can be declared in
the `services.limavm-nix` option of a `darwinSystem`.  These become
launchd agents on the host.  See the example
[template](./templates/darwin-host).

One huge, critical difference is that it is generally not possible to
build the disk image for Lima to boot from on Darwin without having
extra tools available on the host, e.g., the service
[`nix.linux-builder`][nix-linux-builder] or Determinate Nix's
[Linux builder][detnix-linux].

Or avoid this by...

### Using a pre-built image

You can also reference an image that already exists somewhere to boot
from, which is kind of how it works in a "normal" use of Lima: you
invoke `limactl` and specify in CLI options some provided
[template](https://lima-vm.io/docs/templates/), which ultimately picks
a pre-existing image for you.

The option `lima.image` accepts a string or path to a qcow2 image to
support this.  This can also be a store path to, e.g., this flake's
`packages.lima-base-image`:

```nix
flake.darwinConfigurations.macbook-pro = inputs.darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    inputs.limavm.darwinModules
    {
      system.stateVersion = 5;
      services.limavm-nix = {
        enable = true;
        vms.work-vm = {
          autoStart = true;
          guest.system = "aarch64-linux";
          guest.modules = [
            {
              lima.enable = true;
              lima.image = "${inputs.limavm.packages.aarch64-linux.lima-base-image}/nixos.qcow2";
            }
          ];
        };
      };
    }
  ];
};
```

See the example [template](./templates/prebuilt-image).

This can be combined with the following in order to be able to
construct an arbitrary `nixosSystem` inside a Lima VM without having
to actually build any image on the host, which maybe sounds cooler to
MacOS users.

### Bootstrapped `nixosSystem`

The module options expose `lima.bootstrap`, which can be used to build
a custom `nixosConfigurations.<attr>` into the resulting Lima VM when
it's first booting as a post-action that runs `nixos-rebuild`, rather
than defining the boot image as the base plus custom extension.  This
obviates the need to build any image on the host:

```nix
flake.nixosConfigurations.myvm = nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = [
    limavm.nixosModules.guest
    { lima.enable = true; system.stateVersion = "26.05"; /* your config */ }
  ];
};

# Deployment: thin eval pins the base image and sets the bootstrap target to
# `.#nixosConfigurations.myvm`.
deployment = nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = [
    limavm.nixosModules.guest
    {
      lima.image = "${limavm.packages.aarch64-linux.lima-base-image}/nixos.qcow2";
      lima.mounts = [ { location = toString ./.; writable = false; } ];
      lima.bootstrap = { flake = toString ./.; attr = "myvm"; };
    }
  ];
};
```

### Ad-hoc guest construction

The image and the `lima.yaml` are independent derivations, so it's
possible to evaluate the guest derivation and compose the resulting
YAML with whatever image source is desired:

```nix
guest = limavm.lib.evalGuest {
  inherit pkgs;
  system = "aarch64-linux";
  modules = [ { lima.enable = true; system.stateVersion = "26.05"; } ];
};

# Prebuilt image (URL or local path) so no image build is triggered.
yaml = limavm.lib.withImage {
  inherit pkgs;
  image = "https://example.com/nixos-base.qcow2";
  inherit (guest.config.lima) arch;
} guest.config.system.build.limaSettings;
```

### den integration

If you use the [den](https://den.denful.dev) framework, `lima` is a
den class extending `host` that two batteries are exposed for.

```nix
# Run a list of den hosts as Lima guests on the including host.
den.aspects.my-darwin-host.includes = [
  (den.batteries.limaGuests [
    den.hosts.my-nixos-vm1
    den.hosts.my-nixos-vm2
  ])
];

# `toLima` accepts the full `options.lima` tree and outputs a `packages.<vm>`
# for each of the image, yaml, and `limactl` wrapper.
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

See the example [template](./templates/flake-module).

[Lima]: https://lima-vm.io/
[detnix-linux]: https://discourse.nixos.org/t/determinate-nix-3-8-4-introducing-the-native-linux-builder-for-macos/67617
[nix-linux-builder]: https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-nix.linux-builder.enable
