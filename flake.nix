{
  description = "Lima VM modules using the den framework";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  outputs = inputs: import ./. inputs;

  nixConfig = {
    extra-substituters = [ "https://limavm-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "limavm-nix.cachix.org-1:3tRE+cBpLSZlcb6Mjgxjif+QCG6mJXuDyjyMHHXgx8I="
    ];
  };
}
