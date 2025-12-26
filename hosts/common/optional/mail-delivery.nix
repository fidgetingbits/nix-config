{ config, ... }:
let
  hostSpec = config.hostSpec;
  email = hostSpec.email;
in
{
  mail-delivery = rec {
    enable = true;
    useRelay = hostSpec.isLocal && (!hostSpec.isRoaming);
    emailFrom = email.notifier;
    smtpHost = if useRelay then email.internalServer else email.externalServer;
    smtpPort = if useRelay then 25 else 587;
    smtpUser = if useRelay then hostSpec.hostName else email.notifier;
  };
}
