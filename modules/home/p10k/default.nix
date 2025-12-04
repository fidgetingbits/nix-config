{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.p10k;
in
{
  options.p10k.enable = lib.mkEnableOption "Enable powerlevel10k for zsh";
  config = lib.mkIf cfg.enable {
    programs.zsh = {

      initContent = lib.mkBefore ''
        # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
        # Initialization code that may require console input (password prompts, [y/n]
        # confirmations, etc.) must go above this block; everything else may go below.
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '';
      plugins = [
        # This enables powerlevel10k itself
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        # This enables our custom theme
        {
          name = "powerlevel10k-config";
          src = ./.;
          file = "p10k.zsh.theme"; # NOTE: Don't use .zsh because of shfmt barfs on it, and can't ignore files
        }

        # FIXME: Make this only apply if we are using catppuccin
        {
          name = "p10k-catppuccin-theme";
          src = ./.;
          file = "mocha.p10k.zsh.theme"; # NOTE: Don't use .zsh because of shfmt barfs on it, and can't ignore files
        }
      ];
    };
  };
}
