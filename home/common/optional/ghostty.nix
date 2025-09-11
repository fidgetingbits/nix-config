{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.unstable.ghostty;
    settings = {
      keybind = [
        # This conflicts with GTK Inspector (needed if ghostty crashes to find gtk info)
        # gsettings set org.gtk.Settings.Debug enable-inspector-keybinding true
        "ctrl+shift+i=unbind"
        # Remap to avoid conflict with GTK Inspector
        "ctrl+shift+d=inspector:toggle"
        # Fix fixterm conflict with zsh ^[ character https://github.com/ghostty-org/ghostty/discussions/5071
        "ctrl+left_bracket=text:\\x1b"
      ];
    };
  };
}
