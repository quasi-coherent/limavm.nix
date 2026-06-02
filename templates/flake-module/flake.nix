{
  description = "Aspect-based VM config with den";

  inputs.den.url = "github:denful/den";
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.darwin.url = "github:LnL7/nix-darwin";
  inputs.darwin.inputs.nixpkgs.follows = "nixpkgs";
  inputs.limavm.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      modules = [ (inputs.import-tree ./modules) ];
      specialArgs = { inherit inputs; };
    }).config.flake;
}
