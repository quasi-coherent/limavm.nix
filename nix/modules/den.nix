{
  den,
  lib,
  ...
}:
let
  hostsList = lib.pipe den.hosts [
    lib.attrValues
    (lib.concatMap lib.attrValues)
    (lib.filter (h: h.class == "nixos"))
  ];
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = lib.listToAttrs (
        map (host: {
          name = host.name;
          value = pkgs.callPackage ../lib/den-package.nix { inherit den host; };
        }) hostsList
      );
    };
}
