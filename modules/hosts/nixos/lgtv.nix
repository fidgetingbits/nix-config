{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.lgtv-control;

  lgtv-on = pkgs.writeShellApplication {
    name = "lgtv-on";
    runtimeInputs = [ pkgs.wakeonlan ];
    text = ''
      # Sometimes takes a really long time for TV to wake up, so try many times
      for _ in {1..10}; do
        wakeonlan ${cfg.mac} -i ${cfg.ip}
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
      lgtv-ip-control --host ${cfg.ip} --mac ${cfg.mac} --keycode "$KEY" power off
    '';
  };
in
{
  options = {
    services.lgtv-control = {
      enable = lib.mkEnableOption "Auto LGTV on/off and control";
      user = lib.mkOption {
        type = lib.types.str;
        default = config.hostSpec.primaryUsername;
        description = "User running services/tools that will access secret lgtv keycode";
      };
      ip = lib.mkOption {
        type = lib.types.str;
        description = "IP address of the TV network card you will be waking";
      };
      mac = lib.mkOption {
        type = lib.types.str;
        description = "MAC address of the TV network card you will be waking";
      };
    };
  };
  config = lib.mkIf cfg.enable {
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
      "keys/lgtv" =
        let
          user = config.users.users.${cfg.user};
        in
        {
          owner = user.name;
          inherit (user) group;
        };
    };
  };
}
