{
  #config,
  ...
}:
{
  # FIXME: Make these use the config.monitors list after it's working
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "roaming";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            mode = "3840x2160@60.00Hz";
            scale = 2.0;
          }
        ];
      }
      {
        profile.name = "home";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "HDMI-A-1";
            status = "enable";
            scale = 1.0;
            mode = "2560x2880@29.99Hz";
          }
        ];
      }
    ];
  };
}
