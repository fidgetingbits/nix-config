{
  config,
  pkgs,
  ...
}:
let
  lgtv-on = pkgs.writeShellScript "lgtv-on" ''
    MAC=${config.hostSpec.networking.subnets.tv.hosts.ogle.mac}
    IP=${config.hostSpec.networking.subnets.tv.hosts.ogle.ip}
    # Sometimes takes a really long time for TV to wake up, so try many times
    for i in {1..10}; do
      ${pkgs.wakeonlan}/bin/wakeonlan $MAC -i $IP
      sleep 5
    done
    exit 0
  '';
  lgtv-off = pkgs.writeShellScript "lgtv-off" ''
    KEY=$(cat ${config.sops.secrets."keys/lgtv".path})
    MAC=${config.hostSpec.networking.subnets.tv.hosts.ogle.mac}
    IP=${config.hostSpec.networking.subnets.tv.hosts.ogle.ip}
    ${pkgs.lgtv-ip-control}/bin/lgtv-ip-control --host $IP --mac $MAC --keycode ''$KEY power off
  '';
in
{
  systemd.services.lgtv-suspend = {
    description = "Turn off LG TV before suspend";
    wantedBy = [
      "sleep.target"
      "suspend.target"
    ];
    before = [
      "sleep.target"
      "suspend.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lgtv-off;
    };
  };

  systemd.services.lgtv-resume = {
    description = "Turn on LG TV after resume";
    wantedBy = [ "post-resume.target" ];
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lgtv-on;
    };
  };

  sops.secrets = {
    "keys/lgtv" = {
      owner = config.users.users.${config.hostSpec.username}.name;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
}
