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

  trioFor =
    pkgs: host:
    let
      vmBuilt = host.instantiate {
        inherit (host) system;
        modules = [
          (den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; }))
        ];
      };
      # Defensive read: hosts that aren't marked by `toLima` won't have imported
      # `lima.nix`, so `config.lima.*` may not exist. Treat absence as "not for us".
      flagged = (vmBuilt.config.lima or { }).enabledForDenHost or false;
    in
    if !flagged then
      null
    else
      import ../lib/limavm-packages.nix {
        inherit pkgs;
        name = host.name;
        nixosSystem = vmBuilt;
      };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = lib.listToAttrs (
        lib.concatMap (
          host:
          let
            trio = trioFor pkgs host;
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
