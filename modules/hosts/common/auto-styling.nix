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

  config = lib.mkIf config.hostSpec.isAutoStyled {
    stylix = {
      enable = true;
      autoEnable = true;
      #      cursor = {
      #        package = pkgs.catppuccin-cursors;
      #        name = "frappeDark";
      #      };
      opacity.terminal = 0.97;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${config.hostSpec.theme}.yaml";
      # FIXME: This needs to be synchronized with fonts.nix
      fonts = rec {
        monospace = {
          name = "FiraCode Nerd Font";
          package = pkgs.nerd-fonts.fira-code;
        };
        sansSerif = monospace;
        serif = monospace;
        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
      image = config.hostSpec.wallpaper;
    };
  };
}
