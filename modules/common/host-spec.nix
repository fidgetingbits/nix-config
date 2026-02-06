# Specifications For Differentiating Hosts
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  options.hostSpec = lib.mkOption {
    type = lib.types.submodule {
      freeformType = with lib.types; attrsOf str;

      options = {
        # Data variables that don't dictate configuration settings
        primaryUsername = lib.mkOption {
          type = lib.types.str;
          description = "The primary administrative username of the host";
        };
        primaryDesktopUsername = lib.mkOption {
          type = lib.types.str;
          description = "The primary desktop user on the host";
          default = config.hostSpec.primaryUsername;
        };
        # FIXME: deprecated. Use either primaryUsername or map over users
        username = lib.mkOption {
          type = lib.types.str;
          description = "The username of the host";
        };
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The hostname of the host";
        };
        email = lib.mkOption {
          type =
            with lib.types;
            let
              leafType = oneOf [
                (listOf str)
                str
                int
              ];
              # Allow any amount of nested attrs
              nestedAttrs = either leafType (attrsOf nestedAttrs);
            in
            nestedAttrs;
          description = "The email of the user";
        };
        work = lib.mkOption {
          default = { };
          type = lib.types.attrsOf lib.types.anything;
          description = "An attribute set of work-related information if isWork is true";
        };
        networking = lib.mkOption {
          default = { };
          type = lib.types.attrsOf lib.types.anything;
          description = "An attribute set of networking information";
        };
        wifi = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Used to indicate if a host has wifi";
        };
        domain = lib.mkOption {
          type = lib.types.str;
          default = "local"; # Need a default for the installer
          description = "The domain of the host";
        };
        userFullName = lib.mkOption {
          type = lib.types.str;
          description = "The full name of the user";
        };
        handle = lib.mkOption {
          type = lib.types.str;
          description = "The handle of the user (eg: github user)";
        };
        # FIXME: This isn't great for multi-user systems
        home = lib.mkOption {
          type = lib.types.str;
          description = "The home directory of the user";
          default =
            let
              user = config.hostSpec.primaryUsername;
            in
            if pkgs.stdenv.isLinux then "/home/${user}" else "/Users/${user}";
        };
        persistFolder = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          description = "The folder to persist data if impermanence is enabled";
          default = null;
        };
        # Configuration Settings
        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "An attribute set of all users on the host";
          default = [ config.hostSpec.username ];
        };
        isMinimal = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a minimal host";
        };
        isImpermanent = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host uses impermanence";
        };
        isProduction = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Indicate a production host";
        };
        isServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a server host";
        };
        isWork = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host that uses work resources";
        };
        isDevelopment = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host used for development";
        };
        isRoaming = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Used to indicate a roaming host for wireless, battery use, etc";
        };
        isRemote = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Used to indicate a host that is remotely managed";
        };
        isLocal = lib.mkOption {
          type = lib.types.bool;
          default = (!config.hostSpec.isRemote);
          description = "Used to indicate a host that is locally managed";
        };
        isAdmin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Used to indicate a host that is used to admin other systems";
        };
        useYubikey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate if the host uses a yubikey";
        };
        voiceCoding = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host that uses voice coding";
        };
        isAutoStyled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host that wants auto styling like stylix";
        };
        theme = lib.mkOption {
          type = lib.types.str;
          #default = "dracula";
          default = "catppuccin-mocha";
          description = "The theme to use for the host (stylix, vscode, neovim, etc)";
        };
        useNeovimTerminal = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host that uses neovim for terminals";
        };
        useWindowManager = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Indicate a host that uses a window manager";
        };
        useAtticCache = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Indicate a host that uses LAN atticd for caching";
        };
        hdr = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host that uses HDR";
        };
        scaling = lib.mkOption {
          type = lib.types.str;
          default = "1";
          description = "Indicate what scaling to use. Floating point number";
        };
        wallpaper = lib.mkOption {
          type = lib.types.path;
          default = "${inputs.nix-assets}/images/wallpapers/jigglypuff.webp";
          description = "Path to wallpaper to use for system";
        };
        useWayland = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate a host that uses Wayland. Both useWayland and useX11 can be true";
        };
        useX11 = lib.mkOption {
          type = lib.types.bool;
          default = config.hostSpec.useWindowManager && (!config.hostSpec.useWayland);
          description = "Indicate a host that uses X11. Both useWayland and useX11 can be true";
        };
        defaultBrowser = lib.mkOption {
          type = lib.types.str;
          default = "firefox";
          description = "The default browser to use on the host";
        };
        defaultEditor = lib.mkOption {
          type = lib.types.str;
          default = "nvim";
          description = "The default editor command to use on the host";
        };
        defaultMediaPlayer = lib.mkOption {
          type = lib.types.str;
          default = "vlc";
          description = "The default video player to use on the host";
        };
        defaultDesktop = lib.mkOption {
          type = lib.types.str;
          default = "gnome";
          description = "The default desktop environment to use on the host";
        };
        # This is needed because nix.nix uses timeZone in both nixos and home context, the latter of which doesnt' have access to time.timeZone
        timeZone = lib.mkOption {
          type = lib.types.str;
          default = "Asia/Taipei";
          description = "Timezone the system is in";
        };
        isAMDGpu = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicate system has a AMD GPUs";
        };
        useVulkan = lib.mkOption {
          type = lib.types.bool;
          default = config.hostSpec.isAMDGpu;
          description = "On systems with AMD GPUs indicates if we should use rocm or vulkan";
        };
        useRocm = lib.mkOption {
          type = lib.types.bool;
          default = config.hostSpec.isAMDGpu && (!config.hostSpec.useVulkan);
          description = "On systems with AMD GPUs indicates if we should use rocm or vulkan";
        };
      };
    };
  };

  config = {
    # FIXME: Add an assertion that the wifi category has a corresponding wifi.<cat>.yaml file in nix-secerts/sops/
    assertions =
      let
        # We import these options to both HM and NixOS, so need to not fail on HM
        isImpermanent =
          config ? "system" && config.system ? "impermanence" && config.system.impermanence.enable;
      in
      [
        {
          assertion =
            !config.hostSpec.isWork || (config.hostSpec.isWork && !builtins.isNull config.hostSpec.work);
          message = "isWork is true but no work attribute set is provided";
        }
        {
          assertion = !isImpermanent || (isImpermanent && !("${config.hostSpec.persistFolder}" == ""));
          message = "config.system.impermanence.enable is true but no persistFolder path is provided";
        }
        {
          assertion = !(config.hostSpec.voiceCoding && config.hostSpec.useWayland);
          message = "Talon, which is used for voice coding, does not support Wayland. See https://github.com/splondike/wayland-accessibility-notes";
        }
        {
          assertion = lib.elem config.hostSpec.primaryUsername config.hostSpec.users;
          message = "primaryUsername doesn't exist in list of users";
        }
      ];
  };
}
