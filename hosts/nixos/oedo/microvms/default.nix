{
  namespace,
  config,
  lib,
  ...
}:
{
  imports = [
    (lib.custom.microvm.mkMicrovms ./.)
  ];

  ${namespace}.microvms.vmLan = config.hostSpec.networking.subnets.p-lan;
}
