{
  config,
  pkgs,
  ...
}:
let
  lgtv-on = pkgs.writeShellScript "lgtv-on" ''
    MAC=${config.hostSpec.networking.subnets.tv.hosts.ogle.mac}
    IP=${config.hostSpec.networking.subnets.tv.hosts.ogle.ip}
    # Retry WoL up to 5 times with increasing delays
    for attempt in {1..5}; do
      echo "WoL attempt $attempt/5 for TV at $IP"
      ${pkgs.wakeonlan}/bin/wakeonlan $MAC -i $IP

      sleep $((attempt * 2))

      # Optional: Test if TV is responding (ping with short timeout)
      if ${pkgs.iputils}/bin/ping -c 1 -W 2 $IP > /dev/null 2>&1; then
        echo "TV is responding after $attempt attempts"
        exit 0
      fi
    done

    echo "TV did not respond after 5 WoL attempts"
    exit 1
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
    after = [ "network-online.target" ];
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
