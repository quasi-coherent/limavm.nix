{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./options.nix
    ./lima.nix
  ];

  lima = {
    enable = true;
    arch = lib.mkDefault "aarch64";
    cpus = lib.mkDefault 2;
    memory = lib.mkDefault "2GiB";
    vmType = lib.mkDefault "vz";
    # Adding headroom for a `nixos-rebuild switch`.
    image.additionalSpace = lib.mkDefault "8G";
  };

  # Need this for the initial boot's rebuild.
  environment.systemPackages = with pkgs; [
    nixos-rebuild
    git
  ];

  users.users.root.password = "";
  system.stateVersion = "26.05";
}
