{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    settings = {
      mgr = {
        ratio = [
          1
          2
          4
        ];
      };
      preview = {
        tab_size = 4;
        image_filter = "lanczos3"; # FIXME: Double check this
        # FIXME: These should be based on config.monitors settings probably
        max_width = 1920;
        max_height = 1080;
        image_quality = 90;
      };
    };
    plugins = { inherit (pkgs.yaziPlugins) toggle-pane; };
    keymap.mgr.prepend_keymap = [
      {
        desc = "Maximize or restore the preview pane";
        on = "T";
        run = "plugin toggle-pane max-preview";
      }
    ];
  };
}
