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
  };

  services.ssh-agent.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
