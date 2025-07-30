{ pkgs, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty.overrideAttrs (_: {
      # https://github.com/NixOS/nixpkgs/issues/421442
      preBuild = lib.optionalString (lib.versionOlder pkgs.unstable.linux.version "6.15.5") ''
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
        # Fix fixterm conflict with zsh ^[ character https://github.com/ghostty-org/ghostty/discussions/5071
        "ctrl+left_bracket=text:\\x1b"
      ];
    };
  };
}
