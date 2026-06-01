{
  den,
  lib,
  config,
  ...
}:
let
  # Expose `packages.<system>.<name>` for each den host with a non-empty
  # intoAttr, running `limactl start` against the guest's built lima.yaml.
  limaRunners = lib.pipe den.hosts [
    lib.attrValues
    (lib.concatMap lib.attrValues)
    (map (
      host:
      let
        osConf = lib.attrByPath host.intoAttr null config.flake;
        guestCfg = osConf.config or null;
        limaYaml = guestCfg.system.build.limaYaml or null;
        limaImage = guestCfg.system.build.limaImage or null;
      in
      if (limaYaml == null) || (host.intoAttr == [ ]) then
        { }
      else
        {
          ${host.system}.${host.name} =
            let
              pkgs = import host.nixpkgs { inherit (host) system; };
            in
            pkgs.writeShellApplication {
              name = host.name;
              runtimeInputs = [ pkgs.lima ];
              text = ''
                ${pkgs.coreutils}/bin/true ${limaImage}
                exec limactl start --tty=false --name=${host.name} ${limaYaml}
              '';
            };
        }
    ))
  ];
in
{
  config.flake.packages = lib.mkMerge limaRunners;
}
