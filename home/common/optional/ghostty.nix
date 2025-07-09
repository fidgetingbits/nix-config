{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    # Relevant until linux kernel 6.15.5 or later
    # See: https://github.com/NixOS/nixpkgs/issues/421442
    package = pkgs.ghostty.overrideAttrs (_: {
      preBuild = ''
        shopt -s globstar
        sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
        shopt -u globstar
      '';
    });
    settings = {
      keybind = [
        # This conflicts with GTK Inspector (needed if ghostty crashes to find gtk info)
        # gsettings set org.gtk.Settings.Debug enable-inspector-keybinding true
        "ctrl+shift+i=unbind"
        # Remap to avoid conflict with GTK Inspector
        "ctrl+shift+d=inspector:toggle"
      ];
    };
  };
}
