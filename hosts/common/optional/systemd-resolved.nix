{ lib, ... }:
{
  networking.useDHCP = lib.mkForce true;
  services.resolved = {

    enable = true;
    llmnr = "false"; # Prevent listening on 0.0.0.0:5355 as we don't need multicast DNS on LAN
    # dnssec breaks on ogre
    # dnssec = "true";
    domains = [ "~." ];
    # FIXME: Fix fallbacks so it definitely goes through LAN dns first...
    #    fallbackDns = [
    #      # LibreDNS
    #      "116.202.176.26#dot.libredns.gr"
    #      # Cloudflare
    #      "1.1.1.1#one.one.one.one"
    #      "1.0.0.1#one.one.one.one"
    #    ];
    #dnsovertls = "true";
  };
}
