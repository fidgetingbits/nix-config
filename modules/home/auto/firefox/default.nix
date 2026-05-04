{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
# See introdus for main shared settings
lib.mkIf config.programs.firefox.enable {
  introdus.firefox = {
    extensions = [ (import ./extensions.nix { inherit pkgs inputs lib; }) ];
    search = [ (import ./search.nix { inherit lib pkgs; }) ];
  };

  # See https://github.com/DivitMittal/firefox-nixCfg/blob/dc55e3750eac4d6381301901e269106efae621ff/config/tridactyl/config/tridactylrc
  # for more examples (and tridactyl repo)
  xdg.configFile."tridactyl/tridactylrc".text =
    let
      # FIXME: Make this an option elsehwere
      # theme = "catppuccin-${config.catppuccin.flavor}";
      theme = "catppuccin-mocha";
    in
    ''
      " Set colorscheme
      " FIXME: change URL when repo is made official: https://github.com/catppuccin/catppuccin/issues/2799
      colourscheme --url https://raw.githubusercontent.com/devnullvoid/tridactyl/catppuccin-review-changes/themes/${theme}.css ${theme}

      " Set text editor for editing text fields (ctrl+i)
      set editorcmd handlr launch text/plain --

      " Don't use uppercase key for hint, since you don't press shift+key
      set hintuppercase false

      " Prevent changing the color elements. Only show the key hint
      " From here: https://github.com/jrolfs/gruvbox-material-tridactyl/issues/6
      set hintstyles.fg none
      set hintstyles.bg none

      " Requires you to setup a local http server and startpage
      set newtab http://localhost:80

      " Adjust keybinds to account for vertical tabs
      bind --mode=normal J tabnext
      bind --mode=normal K tabprev

      " WARNING: This is probably a bad idea, as it disables most clickables, but
      " otherwise it highlights everything. Below doesn't work with image links
      " FIXME: not() may be better: https://github.com/gurpreetatwal/dotfiles/blob/81a14847f7c9aaf746e4e3852c4e61f4640bbac8/tridactylrc#L36
      "
      " ---
      " Result URL:             [data-testid="result-title-a"]
      " Result base site URL:   [data-testid="result-extras-url-link"]
      " ---
      " bindurl ^https://duckduckgo.com f hint -Jc [data-testid="result-title-a"], [data-testid="result-extras-url-link"]
    '';
  programs.firefox.nativeMessagingHosts = [ pkgs.tridactyl-native ];

}
