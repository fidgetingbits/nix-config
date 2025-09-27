{
  pkgs,
  #  config,
  #  lib,
  ...
}:
# https://www.reddit.com/r/NixOS/comments/innzkw/pihole_style_adblock_with_nix_and_unbound/

let
  adblockLocalZones = pkgs.stdenv.mkDerivation {
    name = "unbound-zones-adblock";

    # FIXME: This should just use the flake input we setup
    src = (
      pkgs.fetchFromGitHub {
        owner = "StevenBlack";
        repo = "hosts";
        rev = "3.13.11";
        sha256 = "sha256-4UXzwq/vsOlcmZYOeeEDEm2hX93q4pBA8axA+S1eUZ8=";
      }
      + "/hosts"
    );

    phases = [ "installPhase" ];

    installPhase = ''
      ${pkgs.gawk}/bin/awk '{sub(/\r$/,"")} {sub(/^127\.0\.0\.1/,"0.0.0.0")} BEGIN { OFS = "" } NF == 2 && $1 == "0.0.0.0" { print "local-zone: \"", $2, ".\" static"}' $src | tr '[:upper:]' '[:lower:]' | sort -u >  $out
    '';
  };
in
{
  systemd.suppressedSystemUnits = [ "systemd-resolved.service" ];

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];

  services.unbound = {

    enable = true;
    resolveLocalQueries = false;

    settings = {
      server = {
        interface = [ "0.0.0.0" ];
        access-control = [
          "127.0.0.0/24 allow"
        ];
        domain-insecure = [ ];
        private-domain = [ ];
        local-zone = [

        ];
        local-data = [
        ];
      };
      forward-zone = [
      ];
      server.so-reuseport = "yes";
      server.include = [ "${adblockLocalZones}" ];
    };

  };

}
