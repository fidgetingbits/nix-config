# Core home functionality that will only work on Linux
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./timers/trash-empty.nix
  ];
  home = rec {
    homeDirectory = config.hostSpec.home;
    username = config.hostSpec.username;
    sessionPath = lib.flatten (
      [
        "${homeDirectory}/scripts/"
      ]
      ++ lib.optional config.hostSpec.voiceCoding [ "${homeDirectory}/scripts/talon/" ]
      ++ lib.optional config.hostSpec.isWork inputs.nix-secrets.work.extraPaths
    );

    packages = lib.optionals (config.hostSpec.isProduction) (
      builtins.attrValues {
        inherit (pkgs)
          e2fsprogs # lsattr, chattr
          cntr # nixpkgs sandbox debugging
          strace
          steam-run # run non-NixOS-packaged binaries on Nix
          copyq # clipboard manager
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
  };

  services.ssh-agent.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
