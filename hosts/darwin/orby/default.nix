# Macbook M1
{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = lib.flatten [
    inputs.mac-app-util.darwinModules.default
    (map lib.custom.relativeToRoot [
      # inputs.sops-nix.nixosModules.sops
      # It would be nice if this didn't have to be repeated per host
      # inputs.home-manager.darwinModules.home-manager
      "hosts/common/core"
      "hosts/common/core/darwin.nix"
      # FIXME: homebrew itself should be core, but packages should be per host
      "hosts/common/darwin/homebrew.nix"
      #../common/optional/yubikey/darwin.nix
      #"hosts/common/optional/msmtp.nix"
    ])
  ];

  hostSpec = {
    hostName = "orby";
    isWork = lib.mkForce true;
    voiceCoding = lib.mkForce true;
    useYubikey = lib.mkForce true;
    isDarwin = lib.mkForce true;
    wifi = lib.mkForce true;
    useNeovimTerminal = lib.mkForce true;
    isProduction = lib.mkForce true;
  };

  environment.systemPackages = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
  security.pam.enableSudoTouchIdAuth = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  networking.computerName = config.hostSpec.hostName;

  #services.backup = {
  #  enable = true;
  #  borgBackupStartTime = "05:00:00";
  # /.cache isn't writable on darwin
  #  borgCacheDir = "/var/root/.cache/borg";
  #};

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  # system.stateVersion = 4;

  # FIXME(orby): System settings that we want:
  # - Battery efficiency only when on battery
  # - Don't sleep when lid is open for 3 hours
  # - don't put recent items in the doc
  # References:
  #   https://github.com/sxyazi/dotfiles/blob/308a294304918198d484bc3fbc249be5c238d158/nix/darwin/default.nix
  #   https://github.com/berbiche/dotfiles/tree/a935f29b6c5429605f8f4be97dbe1593ee906e9b

  # See: https://github.com/sxyazi/dotfiles/blob/308a294304918198d484bc3fbc249be5c238d158/nix/darwin/default.nix
  # https://alexpeattie.com/blog/associate-source-code-files-with-editor-in-macos-using-duti/
  # https://apple.stackexchange.com/questions/123833/replace-text-edit-as-the-default-text-editor

  # Switch the using:
  # https://github.com/jdek/openwith/blob/master/openwith.swift

  system = {
    # Lifted from: https://github.com/gilacost/dot-files/blob/master/darwin-configuration.nix
    defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
        orientation = "bottom";
        showhidden = true;
        static-only = true;
      };
      # Confirm if we can just use finder here?
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
      };
    };

    # FIXME(duti): Make the application configurable probably, in case we want to use vim on one. This could likely tie
    # into options that are set for both nixos with xdg and darwin with duti
    # Put it in a lib.map
    activationScripts.setting.text = ''
      curl "https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml" \
      | yq - r "to_entries | (map(.value.extensions) | flatten) - [null] | unique | .[]" \
      | xargs - L 1 - I "{}" duti - s com.microsoft.VSCode { } all

        # Use duti to set defaults for specific files to VSCode
        duti -s com.microsoft.VSCode .txt all
        duti -s com.microsoft.VSCode .ass all
        duti -s com.microsoft.VSCode public.plain-text all
        duti -s com.microsoft.VSCode public.source-code all
        duti -s com.microsoft.VSCode public.data all
        duti -s com.microsoft.VSCode .css all
        duti -s com.microsoft.VSCode .csv all
        duti -s com.microsoft.VSCode public.comma-separated-values-text all
        duti -s com.microsoft.VSCode public.text all
        duti -s com.microsoft.VSCode public.item all
        duti -s com.microsoft.VSCode public.content all
        duti -s com.microsoft.VSCode public.delimited-values-text all
        duti -s com.microsoft.VSCode .gitattributes all
        duti -s com.microsoft.VSCode .gitignore all
        duti -s com.microsoft.VSCode .htaccess all
        duti -s com.microsoft.VSCode .js all
        duti -s com.microsoft.VSCode .json all
        duti -s com.microsoft.VSCode .link all
        duti -s com.microsoft.VSCode .md all
        duti -s com.microsoft.VSCode .mv all
        duti -s com.microsoft.VSCode .mvt all
        duti -s com.microsoft.VSCode .scss all
        duti -s com.microsoft.VSCode .sh all
        duti -s com.microsoft.VSCode .txt all
        duti -s com.microsoft.VSCode .xml all
        duti -s com.microsoft.VSCode .yaml all
        duti -s com.microsoft.VSCode .zsh all
    '';
  };

  system.stateVersion = 5;
}
