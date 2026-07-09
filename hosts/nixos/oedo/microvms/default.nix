{
  namespace,
  config,
  lib,
  ...
}:
{
  imports = [
    (lib.custom.microvms.mkMicrovms ./.)
  ];

  ${namespace}.microvms.vmLan = config.hostSpec.networking.subnets.p-lan;
}
