{ ... }:
{
  wayland.windowManager.hyprland.settings.windowrule = [
    #
    # ========== Float on launch ==========
    #
    "float, class:^(galculator)$"
    "float, class:^(waypaper)$"

    # Dialog windows
    "float, title:^(Open File)(.*)$"
    "float, title:^(Select a File)(.*)$"
    "float, title:^(Choose wallpaper)(.*)$"
    "float, title:^(Open Folder)(.*)$"
    "float, title:^(Save As)(.*)$"
    "float, title:^(Library)(.*)$"
    "float, title:^(Accounts)(.*)$"
    "float, title:^(Text Import)(.*)$"
    "float, title:^(File Operation Progress)(.*)$"
    #"float, focus 0, title:^()$, class:^([Ff]irefox)"
    "float, noinitialfocus, title:^()$, class:^([Ff]irefox)"
  ];

}
