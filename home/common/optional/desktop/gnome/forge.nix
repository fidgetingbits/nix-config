{ pkgs, ... }:
{
  home.packages = [ pkgs.gnomeExtensions.forge ];
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        #"forge@jmmaranan.com"
      ];
    };
    # Lots of settings here:    # https://github.com/heywoodlh/flakes/blob/c221dc68718ebc5ad0df2eeaf0b97b3de970b7c0/gnome/flake.nix#L243

    #         [org/gnome/shell/extensions/forge/keybindings]
    #    window-snap-two-third-left=['<Control><Alt>e']
    #    window-snap-two-third-right=@as []
    #    window-swap-last-active=@as []
    #    window-toggle-float=['<Super>y']
    "org/gnome/shell/extensions/forge" = {
      window-gap-hidden-on-single = false;
      window-gap-size = 8;
      window-gap-size-increment = 2;
      workspace-skip-tile = "";
    };
  };
}
