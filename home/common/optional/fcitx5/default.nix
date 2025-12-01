{ pkgs, config, ... }:
{

  home.file = {
    ".config/fcitx5/.keep".text = "# Managed by Home Manager";
  };

  xdg.configFile = {
    "fcitx5/profile" = {
      source = ./profile;
      # every time fcitx5 switch input method, it will modify ~/.config/fcitx5/profile,
      # so we need to force replace it in every rebuild to avoid file conflict.
      force = true;
    };
    #"fcitx5/conf/classicui.conf".source = ./classicui.conf;
    # Disable ctrl-; key for clipboard (probably just disable tthis eventually, since we use rofi-copyq now
    "fcitx5/conf/clipboard.conf" = {
      force = true;
      text = ''
        # Trigger Key
        TriggerKey=
        # Paste Primary
        PastePrimaryKey=
        # Number of entries
        Number of entries=5
        # Do not show password from password managers
        IgnorePasswordFromPasswordManager=False
        # Hidden clipboard content that contains a password
        ShowPassword=False
        # Seconds before clearing password
        ClearPasswordAfter=30
      '';
    };
  };
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;

    fcitx5 = {
      addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        qt6Packages.fcitx5-configtool # Might need to enable rime using configtool after installed
        fcitx5-table-extra
        fcitx5-chewing # Adds zhuyin https://fcitx-im.org/wiki/Chewing
        fcitx5-rime
        fcitx5-gtk
        libsForQt5.fcitx5-qt
      ];
      waylandFrontend = config.hostSpec.useWayland;
    };
  };
}
