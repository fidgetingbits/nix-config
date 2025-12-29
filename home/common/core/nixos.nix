# Core home functionality that will only work on Linux
{
  osConfig,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # FIXME: Move this to trash module that we enable for users instead
    ./timers/trash-empty.nix
  ];
  home = {
    packages = lib.optionals (osConfig.hostSpec.isProduction) (
      lib.attrValues {
        inherit (pkgs)
          e2fsprogs # lsattr, chattr
          cntr # nixpkgs sandbox debugging
          strace
          steam-run # run non-NixOS-packaged binaries on Nix
          trash-cli # tools for managing trash
          socat # General networking utility, ex: used for serial console forwarding over ssh
          ;
      }
    );
    # Reload font cache on rebuild to avoid issues similar to
    # https://www.reddit.com/r/NixOS/comments/1kwogzf/after_moving_to_2505_system_fonts_no_longer/
    activation.reloadFontCache = lib.hm.dag.entryAfter [ "linkActivation" ] ''
      if [ -x "${pkgs.fontconfig}/bin/fc-cache" ]; then
        ${pkgs.fontconfig}/bin/fc-cache -f
      fi
    '';

    sessionVariables = {

    }
    // lib.optionalAttrs osConfig.hostSpec.useWayland {
      QT_QPA_PLATFORM = "wayland";
      GDK_BACKEND = "wayland";
      CLUTTER_BACKEND = "wayland"; # for gnome-shell
      SDL_VIDEODRIVER = "wayland"; # for SDL apps
      NIXOS_OZONE_WL = "1"; # for chromium, vscode, electron, etc
      XDG_SESSION_TYPE = "wayland";
      # Set by firefox wrapper in nixpkgs, but just in case it's used outside the wrapper?
      MOZ_ENABLE_WAYLAND = "1";

    };
  };

  services.ssh-agent.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
