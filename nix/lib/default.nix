let
  defaultNativeSys =
    guestSystem: pkgs:
    let
      inherit (pkgs) lib;
      arch = lib.head (lib.splitString "-" guestSystem);
    in
    [
      "${arch}-darwin"
      "${arch}-linux"
    ];

  # The `lima.yaml` file minus the `images`, which contains the sha of the boot
  # image we have to build, which means we would have to build the whole thing
  # to build the YAML.
  #
  # It's in our interest to separate the two; I shouldn't have to build an 8 GiB
  # VM to turn some module options into YAML.  This forces evaluation of all the
  # module options except for the image, which is evaluated at some point anyway.
  #
  # This way we can test the module options without having to download and install
  # 45k packages.
  evalLimaYaml =
    { config, pkgs, ... }:
    let
      inherit (import ./system-build.nix { inherit config pkgs; }) limaSettings;
      limaYaml = (pkgs.formats.yaml { }).generate "eval.yaml" limaSettings;
    in
    limaYaml;

  # `lima.yaml` for the `limactl` CLI.
  mkLimaYaml =
    { config, pkgs, ... }:
    let
      inherit (import ./system-build.nix { inherit config pkgs; }) limaImage limaSettings;
      images = [
        {
          inherit (config.lima) arch;
          location = "${limaImage}/nixos.qcow2";
        }
      ];
      merged = limaSettings // {
        inherit images;
      };
      limaYaml = (pkgs.formats.yaml { }).generate "lima.yaml" merged;
    in
    limaYaml;

  # Creates the Lima YAML config from an ad-hoc NixOS declaration.
  mkGuestYaml = import ./mk-guest-yaml.nix;

  # Create the `limactl` wrapper package for the configured options.
  mkLctl =
    {
      config,
      pkgs,
      name,
      ...
    }:
    let
      limaYaml = mkLimaYaml { inherit config pkgs; };
    in
    pkgs.callPackage ./limactl.nix { inherit limaYaml name; };

  # List of `lctl-${host.name}` packages for each den host that includes a
  # corresponding Lima VM.
  den.mkLimaPkgs =
    {
      config,
      inputs,
      lib,
      ...
    }:
    let
      inherit (inputs) nixpkgs den;
      pkgsFor = sys: nixpkgs.legacyPackages.${sys};
      cfg = config.lima;

      runnerFor =
        host: sys:
        let
          pkgs = pkgsFor sys;
        in
        pkgs.callPackage ./den-package.nix { inherit den host; };

      mkLimaPkg =
        host:
        let
          sys = if cfg.nativeSys != [ ] then cfg.nativeSys else defaultNativeSys host.system;
        in
        lib.listToAttrs (
          map (s: {
            name = s;
            value.${host.name} = runnerFor host s;
          }) sys
        );

      limaPkgs = lib.pipe den.hosts [
        lib.attrValues
        (lib.concatMap lib.attrValues)
        (lib.filter (h: h.class == "nixos"))
        (map mkLimaPkg)
        (lib.foldl' lib.recursiveUpdate { })
      ];
    in
    limaPkgs;
in
{

  inherit
    den
    evalLimaYaml
    mkGuestYaml
    mkLctl
    mkLimaYaml
    ;
}
