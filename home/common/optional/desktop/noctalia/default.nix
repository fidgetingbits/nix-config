{
  # config,
  inputs,
  lib,
  pkgs,
  osConfig,
  # config,
  ...
}:
let
  # Catppuccin Mocha Palette
  # mocha = {
  #   base = "#1e1e2e";
  #   mantle = "#181825";
  #   crust = "#11111b";
  #   text = "#cdd6f4";
  #   subtext0 = "#a6adc8";
  #   overlay0 = "#6c7086";
  #
  #   mauve = "#cba6f7"; # Primary
  #   lavender = "#b4befe"; # Secondary
  #   pink = "#f5c2e7"; # Tertiary
  #   red = "#f38ba8"; # Error
  # };
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home.packages = [
    pkgs.adwaita-icon-theme
  ];

  # Testing why styling doesn't work
  # stylix.targets.noctalia-shell.disable = true;

  # There are lots more settings, see here: https://github.com/Suhail-liahuS/Nyx/blob/82317deb507686b1d434265f2c9a76b4df6dc2df/modules/home/noctalia/default.nix#L64
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings =
      let
        baseSettings = import ./settings.nix { inherit inputs; };
        hostConfigPath = lib.custom.relativeToRoot "hosts/nixos/${osConfig.hostSpec.hostName}/noctalia.nix";
        hostSettings = if lib.pathExists hostConfigPath then import hostConfigPath else { };
      in
      lib.recursiveUpdate baseSettings hostSettings
      # nixfmt hack
      |> lib.mapAttrs (n: v: lib.mkForce v);
    # colors = {
    #   mPrimary = lib.mkForce mocha.mauve;
    #   mOnPrimary = lib.mkForce mocha.base;
    #
    #   mSecondary = lib.mkForce mocha.lavender;
    #   mOnSecondary = lib.mkForce mocha.base;
    #
    #   mTertiary = lib.mkForce mocha.pink;
    #   mOnTertiary = lib.mkForce mocha.base;
    #
    #   mError = lib.mkForce mocha.red;
    #   mOnError = lib.mkForce mocha.base;
    #
    #   mSurface = lib.mkForce mocha.base;
    #   mOnSurface = lib.mkForce mocha.text;
    #
    #   mSurfaceVariant = lib.mkForce mocha.mantle;
    #   mOnSurfaceVariant = lib.mkForce mocha.subtext0;
    #
    #   mOutline = lib.mkForce mocha.overlay0;
    #   mShadow = lib.mkForce mocha.crust;
    # };

  };
}
