{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.kitty = {
    enable = true;
    extraConfig =
      ''
        # https://sw.kovidgoyal.net/kitty/conf.html
        enable_audio_bell no

        # this needs to be long enough that talon can always get the full value and parse it
        max_title_length 0
        tab_title_max_length 0

        map shift + page_up scroll_page_up
        map shift + page_down scroll_page_down

        map alt+1 goto_tab 1
        map alt+2 goto_tab 2
        map alt+3 goto_tab 3
        map alt+4 goto_tab 4
        map alt+5 goto_tab 5
        map alt+6 goto_tab 6
        map alt+7 goto_tab 7
        map alt+8 goto_tab 8
        map alt+9 goto_tab 9
      ''
      + lib.optionalString config.hostSpec.useNeovimTerminal ''
        shell "${pkgs.neovim-term}/bin/neovim-term.sh"
      '';
  };
}
