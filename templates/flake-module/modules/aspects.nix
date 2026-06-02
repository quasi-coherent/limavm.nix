{ ... }:
{
  # Shared base config every guest gets.
  den.aspects.base.nixos = {
    users.users.root.password = "";
    users.users.dev = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = "";
    };
    system.stateVersion = "26.05";
  };

  den.aspects.dev-tools.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        emacs30
        fd
        jq
        git
        ripgrep
      ];
    };

  den.aspects.nginx.nixos = {
    services.nginx = {
      enable = true;
      virtualHosts."_".root = "/var/www";
    };
    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
