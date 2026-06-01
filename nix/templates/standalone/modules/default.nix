{ den, inputs, ... }:
{
  imports = [
    inputs.den.flakeModule
    inputs.limavm.flakeModules.lima
  ];

  den.schema.host.includes = [ den.batteries.hostname ];
}
