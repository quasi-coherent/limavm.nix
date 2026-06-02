{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModules.default
    inputs.limavm.flakeModules.den
  ];
}
