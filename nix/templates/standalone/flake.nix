{
  description = "Intrinsic VM definition, ran as a flake package";

  inputs.den.url = "github:denful/den";
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.darwin.url = "github:nix-community/nix-darwin";
  inputs.darwin.inputs.nixpkgs.follows = "nixpkgs";
  inputs.limavm-nix.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      modules = [ (inputs.import-tree ./modules) ];
      specialArgs = { inherit inputs; };
    }).config.flake;
}
