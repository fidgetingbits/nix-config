{
  pkgs,
  ...
}:
{
  programs.wlogout =
    let
      lockAction = "${pkgs.hyprlock}/bin/hyprlock";
    in
    {
      enable = true;
      layout = [
        {
          label = "lock";
          action = lockAction;
          text = "Loc[k]";
          keybind = "k";
        }
        {
          label = "hibernate";
          action = "${lockAction} & systemctl hibernate";
          text = "[H]ibernate";
          keybind = "h";
        }
        {
          label = "suspend";
          action = "${lockAction} & systemctl suspend";
          text = "[S]uspend";
          keybind = "s";
        }
        {
          label = "logout";
          action = "uwsm stop";
          text = "[L]ogout";
          keybind = "l";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutd[o]wn";
          keybind = "o";
        }
        {
          label = "screen off";
          action = "${lockAction} & niri msg action power-off-monitors";
          text = "Screen Of[f]";
          keybind = "f";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "[R]eboot";
          keybind = "r";
        }
      ];
    };
}
