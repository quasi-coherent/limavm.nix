<h2 align="center">limavm.nix</h2>

A flake for building and running [Lima]-managed VMs on macOS or Linux hosts.

## Usage

```nix
inputs.limavm.url = "github:quasi-coherent/limavm.nix";
inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

# WIP: To get the cached Lima base image.
nixConfig = {
  extra-substituters = [ "https://limavm-nix.cachix.org" ];
  extra-trusted-public-keys = [
    "limavm-nix.cachix.org-1:3tRE+cBpLSZlcb6Mjgxjif+QCG6mJXuDyjyMHHXgx8I="
  ];
};
```

The flake exposes the conventional modules:

| Output                      | Runs guests via      |
| --------------------------- | -------------------- |
| `darwinModules.lima` | `launchd.user.agents` |
| `nixosModules.lima` | `systemd.services` |
| `flakeModules.home-manager` | One or the other |
| `flakeModules.den` | See [below](#den-integration) |

It also exposes `limavm-nix.packages.{system}.lima-base-image` for aarch64-linux, x86_64-linux.
This is a pre-built Lima disk image that a minimal nixOS VM can boot from.  `TODO(me)` pending,
this `lima-base-image` will be available in the public cachix cache `limavm-nix` so that users
can reference it to avoid lengthy image builds or to avoid building an image altogether.

Each of the modules offer different ways to get a Lima VM that have different requirements for
different host systems:

#### NixOS host and NixOS guest

One or more `nixosSystem`s can be declared in a `services.limavm-nix` configuration.  These
ultimately become systemd services in the `nixosSystem` that set the option.

See the [template](./templates/nixos-host) example.

#### Darwin host and NixOS guest

In an identical fashion, one or more `nixosSystem`s can be declared in the `services.limavm-nix`
option of a `darwinSystem`.  These become launchd agents on the host.  See the example
[template](./templates/darwin-host).

One huge, critical difference is that it is generally not possible to build the disk image for
Lima to boot from on Darwin without having extra tools available on the host, e.g., the service
[`nix.linux-builder`][nix-linux-builder] or Determinate Nix's [Linux builder][detnix-linux].

#### Using a pre-built image

One can avoid building a Lima boot image by referencing one that already exists, just like it
works in a "normal" use of Lima, where a user invokes `limactl` and specifies in CLI options a
[template](https://lima-vm.io/docs/templates/), which sets a URL to a pre-built image.

The option `lima.image` accepts a string or path to a qcow2 image to support this.  This can also
be a store path to, e.g., this flake's `packages.lima-base-image`:

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

#### den integration

If you use the [den](https://den.denful.dev) framework, `lima` is a den class extending `host` that two
batteries are exposed for.

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

### Ad-hoc guest construction

The image and the `lima.yaml` are independent derivations, so it's possible to evaluate the guest
derivation and compose the resulting YAML with whatever image source is desired:

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

### Bootstrapped `nixosSystem`

The module options expose `lima.bootstrap`, which can be used to build a custom
`nixosConfigurations.<attr>` via `nixos-rebuild switch --flake` into the resulting Lima VM on first
boot, obviating the need to build the disk image on the host:

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

## TODO

1. Push `lima-base-image` to cachix as part of release CI so darwin
   consumers don't trip the linux-builder.

[Lima]: https://lima-vm.io/
[detnix-linux]: https://discourse.nixos.org/t/determinate-nix-3-8-4-introducing-the-native-linux-builder-for-macos/67617
[nix-linux-builder]: https://nix-darwin.github.io/nix-darwin/manual/index.html#opt-nix.linux-builder.enable
