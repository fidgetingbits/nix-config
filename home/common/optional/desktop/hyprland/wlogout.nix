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
          text = "Lock";
          keybind = "l";
        }
        {
          label = "hibernate";
          action = "${lockAction} & systemctl hibernate";
          text = "Hibernate";
          keybind = "h";
        }
        {
          label = "logout";
          action = "hyprctl dispatch exit";
          text = "Logout";
          keybind = "x";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutdown";
          keybind = "s";
        }
        {
          label = "suspend";
          action = "${lockAction} & hyprctl dispatch dpms off";
          text = "Screen Off";
          keybind = "u";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot";
          keybind = "r";
        }
      ];
    };
}
