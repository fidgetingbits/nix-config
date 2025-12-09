{
  config,
  pkgs,
  lib,
  ...
}:
let
  lgtv-on = pkgs.writeShellApplication {
    name = "lgtv-on";
    runtimeInputs = [ pkgs.wakeonlan ];
    text = ''
      MAC=${config.hostSpec.networking.subnets.tv.hosts.ogle.mac}
      IP=${config.hostSpec.networking.subnets.tv.hosts.ogle.ip}
      # Sometimes takes a really long time for TV to wake up, so try many times
      for _ in {1..10}; do
        wakeonlan "$MAC" -i "$IP"
        sleep 5
      done
      exit 0
    '';
  };

  lgtv-off = pkgs.writeShellApplication {
    name = "lgtv-off";
    runtimeInputs = [
      pkgs.lgtv-ip-control
    ];
    text = ''
      KEY=$(cat ${config.sops.secrets."keys/lgtv".path})
      MAC=${config.hostSpec.networking.subnets.tv.hosts.ogle.mac}
      IP=${config.hostSpec.networking.subnets.tv.hosts.ogle.ip}
      lgtv-ip-control --host "$IP" --mac "$MAC" --keycode "$KEY" power off
    '';
  };
in
{
  environment.systemPackages = [
    lgtv-on
    lgtv-off
  ];
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
      ExecStart = lib.getExe' lgtv-off "lgtv-off";
    };
  };

  systemd.services.lgtv-resume = {
    description = "Turn on LG TV after resume";
    wantedBy = [
      "post-resume.target"
    ];
    requires = [
      "network-online.target"
    ];
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe' lgtv-on "lgtv-on";
    };
  };

  sops.secrets = {
    "keys/lgtv" = {
      owner = config.users.users.${config.hostSpec.username}.name;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
}
