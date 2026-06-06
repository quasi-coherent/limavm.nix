{
  description = "Lima VM modules using the den framework";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  inputs.nixpkgs-lib.follows = "nixpkgs";
  outputs = inputs: import ./. inputs;

  nixConfig = {
    extra-substituters = [ "https://limavm-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "limavm-nix.cachix.org-1:3tRE+cBpLSZlcb6Mjgxjif+QCG6mJXuDyjyMHHXgx8I="
    ];
  };
}
