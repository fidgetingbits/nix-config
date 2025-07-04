{ config, pkgs, ... }:
let
  # FIXME(nzxt): use nix-assets for this
  nzxt-kraken-image = "${config.hostSpec.home}/images/nzxt/main.gif";
in
{
  imports = [
    ./liquidctl.nix
  ];
  systemd.services.nzxt-set-image = {
    description = "Set NZXT Kraken image on resume";
    wantedBy = [
      "multi-user.target" # Startup
      "post-resume.target" # Resume
    ];
    after = [
      # For startup
      "basic.target"

      # For resume
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "nzxt-set-image" ''
        if [ ! -f ${nzxt-kraken-image} ]; then
          echo "NZXT Kraken image not found: ${nzxt-kraken-image}";
          exit 1;
        fi
        ${pkgs.liquidctl}/bin/liquidctl -m kraken set lcd screen gif ${nzxt-kraken-image}
      '';
    };
  };
}
