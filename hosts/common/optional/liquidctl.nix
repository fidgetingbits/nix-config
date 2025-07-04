{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.liquidctl ];

  systemd.services.liquidctl = {
    description = "Liquidctl service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [ "${pkgs.liquidctl}/bin/liquidctl initialize all" ];
    };
  };

}
