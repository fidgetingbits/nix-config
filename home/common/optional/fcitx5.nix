{ pkgs, ... }:
{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;

    fcitx5.addons = with pkgs; [
      fcitx5-chinese-addons
      fcitx5-table-extra
      fcitx5-chewing # Adds zhuyin https://fcitx-im.org/wiki/Chewing
      fcitx5-rime
      fcitx5-configtool # Might need to enable rime using configtool after installed
      fcitx5-gtk
      libsForQt5.fcitx5-qt
    ];
    # FIXME: maybe change this, see ryan4yin
    # https://github.com/ryan4yin/nix-config/blob/4ec26c5e5f8fb4e1928f3cb62c1fba857df3f5b0/home/linux/gui/base/fcitx5/default.nix
    fcitx5.ignoreUserConfig = true;
  };
}
