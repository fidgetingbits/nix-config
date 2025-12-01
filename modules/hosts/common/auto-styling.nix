{
  pkgs,
  inputs,
  config,
  lib,
  isDarwin,
  ...
}:
let
  platform = if isDarwin then "darwin" else "nixos";
  platformModules = "${platform}Modules";
in
{
  imports = [
    inputs.stylix.${platformModules}.stylix
  ];

  # Also seem modules/home/auto-styling.nix
  config = lib.mkIf config.hostSpec.isAutoStyled {
    stylix = {
      enable = true;
      autoEnable = true;
      opacity.terminal = 0.80;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${config.hostSpec.theme}.yaml";
      # FIXME: This needs to be synchronized with fonts.nix
      fonts = rec {
        monospace = {
          name = "FiraMono Nerd Font";
          package = pkgs.nerd-fonts.fira-mono;
        };
        sansSerif = monospace;
        serif = monospace;
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
      image = config.hostSpec.wallpaper;
    };
  };
}
