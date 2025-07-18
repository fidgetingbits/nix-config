{ ... }:
{
  programs.zellij = {
    enable = true;
    # enableZshIntegration = true; # NOTE: This forces zellij upon opening zsh
    settings = {
      show_startup_tips = false;
      pane_frames = false;
      #default_layout = "compact"; # NOTE: compact removes the keybindings hint
    };
  };

  programs.zsh.shellAliases = {
    zl = "zellij";
    zls = "zellij list-sessions";
  };
  stylix.targets.zellij.enable = true;
}
