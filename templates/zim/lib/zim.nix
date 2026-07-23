{ ... }:
{
  den.aspects.zim = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.zim ];

        services.xserver = {
          enable = true;
          desktopManager.xfce.enable = true;
          displayManager.lightdm.enable = true;
        };

        services.xrdp = {
          enable = true;
          defaultWindowManager = "xfce4-session";
          # This will be forwarded to localhost.
          port = 5555;
          # false by default, but now double false.
          openFirewall = false;
        };
      };
  };
}
