{
  config,
  lib,
  namespace,
  ...
}:
let
  vmBridge = config.${namespace}.microvms.vmBridge;
  networking = config.hostSpec.networking;
  subnets = networking.subnets;
  ports = networking.ports;
  llamaSwapPort = ports.tcp.llama-swap;
in
{
  imports = [
    (lib.custom.microvms.mkMicrovms ./.)
  ];
  ${namespace}.microvms = {
    vmLan = subnets.n-lan;
    # We inject some rules. We may want to just add this where we define llama-swap?
    extraInputRules = [
      "iifname ${vmBridge} ip saddr {${subnets.n-lan.cidr}, ${subnets.p-lan.cidr}} tcp dport ${toString llamaSwapPort} accept"
    ];
  };
}
