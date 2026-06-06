{ lib }:
{
  # Resolved `options.lima` minus the image tag.  We keep that yaml prop out of
  # this to be able to build everything but the giant image in cases where we
  # want that.
  mkLimaSettings = cfg: {
    inherit (cfg)
      vmType
      arch
      cpus
      memory
      disk
      ;
    mountType = cfg.mountType;
    mounts = map (m: { inherit (m) location writable; }) cfg.mounts;
    portForwards = map (p: { inherit (p) guestPort hostPort hostIP; }) cfg.portForwards;
    provision =
      map (s: {
        mode = "system";
        script = s;
      }) cfg.provision.system
      ++ map (s: {
        mode = "user";
        script = s;
      }) cfg.provision.user;
    rosetta = lib.optionalAttrs cfg.rosetta.enabled {
      enabled = true;
      binfmt = true;
    };
    ssh = { inherit (cfg.ssh) loadDotSSHPubKeys localPort; };
  };

  # Turn an attrset into a YAML file derivation.
  renderYaml =
    pkgs: name: value:
    (pkgs.formats.yaml { }).generate name value;

}
