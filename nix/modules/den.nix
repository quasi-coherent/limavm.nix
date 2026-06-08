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
        lib.concatMap (
          host:
          let
            trio = import ../lib/den-package.nix {
              inherit
                pkgs
                lib
                den
                host
                ;
            };
          in
          lib.optionals (trio != null) (
            [
              {
                name = host.name;
                value = trio.start;
              }
              {
                name = "${host.name}-yaml";
                value = trio.yaml;
              }
            ]
            ++ lib.optional (trio.image != null) {
              name = "${host.name}-image";
              value = trio.image;
            }
          )
        ) hostsList
      );
    };
}
