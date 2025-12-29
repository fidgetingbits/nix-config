{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
{
  # FIXME: Add the background sync service
  # https://forum.atuin.sh/t/getting-the-daemon-working-on-nixos/334
  programs.atuin = {
    enable = true;

    enableBashIntegration = false;
    enableZshIntegration = false; # NOTE: false because of zsh-vi-mode, see below
    enableFishIntegration = false;

    settings = {
      auto_sync = true;
      sync_address = "https://atuin.ooze.${osConfig.hostSpec.domain}";
      sync_frequency = "30m";
      update_check = false;
      filter_mode = "global";
      invert = true;
      enter_accept = true;
      show_help = false;
      prefers_reduced_motion = true;

      style = "compact";
      inline_height = 10;
      search_mode = "fuzzy";
      filter_mode_shell_up_key_binding = "session";

      # This came from https://github.com/nifoc/dotfiles/blob/ce5f9e935db1524d008f97e04c50cfdb41317766/home/programs/atuin.nix#L2
      history_filter = [
        "^base64decode"
        "^instagram-dl"
        "^mp4concat"
      ];
    };

    # We use down to trigger, and use up to quickly edit the last entry only
    flags = [ "--disable-up-arrow" ];
  };
  sops.secrets."keys/atuin" = {
    path = "${config.home.homeDirectory}/.local/share/atuin/key";
  };

  programs.zsh.initContent =
    let
      flagsStr = lib.escapeShellArgs config.programs.atuin.flags;
    in
    ''
      # Bind down key for atuin, specifically because we use invert
      bindkey "$key[Down]"  atuin-up-search

      # Work around zsh-vi-mode bug
      # https://github.com/atuinsh/atuin/issues/1826
      if [[ $options[zle] = on ]]; then
        function atuin_init() {
          eval "$(${pkgs.atuin}/bin/atuin init zsh ${flagsStr})"
        }
        zvm_after_init_commands+=(atuin_init)
      fi
    '';
}
