{
  description = "Lima VM modules using the den framework";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  inputs.nixpkgs-lib.follows = "nixpkgs";
  outputs = inputs: import ./. inputs;
}
