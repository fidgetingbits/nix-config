{ config, ... }:
let
  domain = config.hostSpec.domain;
  useRelay = config.mail-delivery.useRelay;
in
{
  mail-delivery = rec {
    enable = true;
    # FIXME: Move this to be defined in hostSpec
    emailFrom = "box@${domain}";
    smtpHost = if useRelay then "mail.${domain}" else "smtp.protonmail.ch";
    smtpPort = if useRelay then 25 else 587;
    smtpUser = if useRelay then config.hostSpec.hostname else emailFrom;
  };
}
