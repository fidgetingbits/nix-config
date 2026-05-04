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
      # theme = "catppuccin-${config.catppuccin.flavor}";
      theme = "catppuccin-mocha";
    in
    ''
      " Set colorscheme
      " TODO: change URL when repo is made official: https://github.com/catppuccin/catppuccin/issues/2799
      colourscheme --url https://raw.githubusercontent.com/devnullvoid/tridactyl/catppuccin-review-changes/themes/${theme}.css ${theme}

      " TODO: set a tab page to startup page

      " FIXME: We probably what to point directly to handlr?
      " Set text editor for editing text fields
      set editorcmd handlr launch text/plain --

      " Adjust keybinds to account for vertical tabs
      bind --mode=normal J tabnext
      bind --mode=normal K tabprev
    '';
  programs.firefox.nativeMessagingHosts = [ pkgs.tridactyl-native ];

}
