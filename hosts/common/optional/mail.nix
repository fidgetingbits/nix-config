{ config, ... }:
let
  useRelay = config.mail-delivery.useRelay;
in
{
  mail-delivery = rec {
    enable = true;
    emailFrom = config.hostSpec.email.notifier;
    smtpHost =
      if useRelay then config.hostSpec.email.internalServer else config.hostSpec.email.externalServer;
    smtpPort = if useRelay then 25 else 587;
    smtpUser = if useRelay then config.hostSpec.hostname else config.hostSpec.email.notifier;
  };
}
