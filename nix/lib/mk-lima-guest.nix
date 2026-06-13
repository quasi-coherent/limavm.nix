{
  nixosSystem,
  lima ? { },
}:
nixosSystem.extendModules {
  modules = [
    ../lima.nix
    {
      lima = lima // {
        enable = true;
      };
    }
  ];
}
