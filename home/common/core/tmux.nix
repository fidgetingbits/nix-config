{ ... }:
{
  programs.tmux = {
    enable = true;
    extraConfig = ''
      # Shut off the bar. We only use tmux to save a single neovim instance per session, so we never need to know it exists.
      if-shell '[ ! -z "$VIMRUNTIME" ]' {
        set -g status off
      }
    '';
  };
}
