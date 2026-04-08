{
  # config,
  inputs,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # Catppuccin Mocha Palette
  mocha = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    text = "#cdd6f4";
    subtext0 = "#a6adc8";
    overlay0 = "#6c7086";

    mauve = "#cba6f7"; # Primary
    lavender = "#b4befe"; # Secondary
    pink = "#f5c2e7"; # Tertiary
    red = "#f38ba8"; # Error
  };
  hostConfig = lib.custom.relativeToRoot "hosts/nixos/${osConfig.hostSpec.hostName}/noctalia.nix";
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ]
  ++ lib.optional (lib.pathExists hostConfig) hostConfig;

  home.packages = [
    # From Mic92:
    # Qt's wayland QPA leaves QIcon::themeName empty so noctalia falls through
    # to hicolor and can't find generic icons like user-desktop. The gtk3
    # platform theme reads gtk-icon-theme-name; ship breeze so that resolves.
    pkgs.kdePackages.breeze-icons
  ];

  # Testing why styling doesn't work
  # stylix.targets.noctalia-shell.disable = true;

  # There are lots more settings, see here: https://github.com/Suhail-liahuS/Nyx/blob/82317deb507686b1d434265f2c9a76b4df6dc2df/modules/home/noctalia/default.nix#L64
  programs.noctalia-shell = {
    enable = true;
    colors = {
      mPrimary = lib.mkForce mocha.mauve;
      mOnPrimary = lib.mkForce mocha.base;

      mSecondary = lib.mkForce mocha.lavender;
      mOnSecondary = lib.mkForce mocha.base;

      mTertiary = lib.mkForce mocha.pink;
      mOnTertiary = lib.mkForce mocha.base;

      mError = lib.mkForce mocha.red;
      mOnError = lib.mkForce mocha.base;

      mSurface = lib.mkForce mocha.base;
      mOnSurface = lib.mkForce mocha.text;

      mSurfaceVariant = lib.mkForce mocha.mantle;
      mOnSurfaceVariant = lib.mkForce mocha.subtext0;

      mOutline = lib.mkForce mocha.overlay0;
      mShadow = lib.mkForce mocha.crust;
    };
    plugins = {
      sources = [
        {
          enabled = true;
          name = "Official Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        privacy-indicator = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        timer = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
      };
      version = 2;
    };
    pluginSettings = {
      privacy-indicator = {
      };
      timer = {
      };
    };
    # FIXME: Merge in per-host entries
    # Settings are kept separate to allow easy `just noctalia-save` updates
    settings = import ./settings.nix { inherit lib; };
  };
}
