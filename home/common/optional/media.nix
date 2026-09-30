{
  pkgs,
  lib,
  ...
}:
{
  home.packages = lib.flatten [
    (lib.attrValues {
      inherit (pkgs)
        ffmpeg
        spicetify-cli
        spotify-player
        ;
      inherit (pkgs.unstable)
        spotify # New enough to hopefully fix stack corruption spam
        ;
      inherit (pkgs.introdus)
        yomitan-api
        ;
    })
  ];

  home.file.".mozilla/native-messaging-hosts/yomitan_api.json".source =
    "${pkgs.introdus.yomitan-api}/lib/mozilla/native-messaging-hosts/yomitan_api.json";

  home.file.".config/mpv/script-opts/yomipv.conf".text = ''
    deck=mandarin
    updater_enabled=no
    selector_show_history=no
    key_selector_lookup=Ctrl+d
    note_tag=yomipv
    miscinfo_episode_label=劇集
    miscinfo_season_label=季
  '';
  /*
    # Preferred dictionary (Senren only)
    dictionary_pref_value=
    #dictionary_pref_value=Jitendex

    # Keybindings
    key_toggle_colorizer="S";
    key_open_selector="c";
    key_selector_confirm="ENTER,c";
    key_selector_cancel="ESC";
    key_selector_left="LEFT";
    key_selector_right="RIGHT";
    key_selector_up="UP";
    key_selector_down="DOWN";
    key_expand_prev="Shift+LEFT";
    key_expand_next="Shift+RIGHT";
    key_selector_lookup="d" # dictionary
    key_selector_lock="v";
    key_toggle_mora_navigation="s";
    key_toggle_selector_trigger_on_mouse_move="z";
    key_append_mode="C";
    key_set_timing_start="q";
    key_set_timing_end="w";
    key_clear_timings="e";
    key_build_ankidb="B";
    key_toggle_picture_animated="g";
    key_toggle_picture_timestamp_source="Ctrl+g";
  */

  programs.mpv = {
    enable = true;
    package = pkgs.mpv.override {
      mpv-unwrapped = pkgs.mpv-unwrapped.override {
        # FIXME: This tries to compile firefox... maybe becomes of rocmSupport?
        ffmpeg = pkgs.ffmpeg-full;
      };

      scripts = lib.attrValues {
        # FIXME: See settings here: https://github.com/donovanglover/nix-config/blob/8b3a33448356b40da856a44cf8f45b3d563466d2/home/mpv.nix#L26
        inherit (pkgs.mpvScripts)
          mpris # control via dbus
          uosc # mouse proximity based UI
          thumbfast # quick thumbnailing preview
          ;
        inherit (pkgs.introdus)
          yomipv
          ;
      };
    };
  };
}
