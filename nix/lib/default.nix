{ ... }:
{
  darwinHost = ./darwin-host.nix;
  nixosHost = ./nixos-host.nix;
  den.mkLimactl = ./limactl.nix;
}
