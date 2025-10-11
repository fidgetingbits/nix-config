{ ... }:
{
  services.sshguard =
    let
      minute = 60;
      hour = minute * 60;
    in
    {
      enable = true;
      blocktime = hour;
      detection_time = 8 * hour;
      blacklist_threshold = 30; # 3 strikes
    };
}
