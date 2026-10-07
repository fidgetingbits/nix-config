# Can get zhuyin cc-cedict library from here
# https://github.com/MarvNC/cc-cedict-yomitan/releases/tag/2026-09-23
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.language-learning;
in
{
  options.${namespace}.language-learning = {
    enable = lib.mkEnableOption "Language learning tools and config";
  };

  config = lib.mkIf cfg.enable {

    home.packages = lib.attrValues {
      # To generate mandarin subtitles for video
      # whisper-ctranslate2 <video> --model large-v3 --language zh --output_format srt
      inherit (pkgs.unstable)
        yt-dlp
        whisper-ctranslate2
        whisperx
        ;
      inherit (pkgs.introdus)
        yomitan-api
        llm-subtrans
        ;
    };

    home.file.".mozilla/native-messaging-hosts/yomitan_api.json".source =
      "${pkgs.introdus.yomitan-api}/lib/mozilla/native-messaging-hosts/yomitan_api.json";

    home.file.".config/mpv/script-opts/yomipv.conf".text = ''
      deck=mandarin
      updater_enabled=no
      selector_show_history=no
      key_selector_lookup=Ctrl+d
      note_tag=yomipv
      miscinfo_episode_label=集
      miscinfo_season_label=季

      # Switched definition_handlebar from selected-dict, as I don't select dictoinaries
      # not entirely clear why: https://github.com/BrenoAqua/Yomipv/blob/main/docs/field_handlebars.md
      definition_handlebar=glossary
    '';
    /*
      # Preferred dictionary (Senren only)
      dictionary_pref_value=single-glossary-cc-cedict-zhuyin-2026-09-22
      #dictionary_pref_value=Jitendex

      # Note fields
      expression_field=word
      expression_furigana_field=
      reading_field=reading
      pitch_accents_field=pitchAccents
      pitch_position_field=pitchPositions
      pitch_categories_field=pitchCategories
      sentence_field=sentence
      sentence_furigana_field=sentenceFurigana
      secondary_sentence_field=sentenceTranslation
      expression_audio_field=wordAudio
      sentence_audio_field=sentenceAudio
      selection_text_field=selectionText
      definition_field=definition
      glossary_field=glossary
      image_field=picture
      freq_sort_field=freqSort
      freq_field=frequencies
      miscinfo_field=miscInfo
      dictionary_pref_field=dictionaryPreference

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
    xdg.configFile = {
      "mpv/scripts/copy_subs.lua".text = # lua
        ''
          local mp = require 'mp'

          local function copy_subtitle()
              local subtitle = mp.get_property("sub-text")

              if not subtitle or subtitle == "" then
                  mp.osd_message("No subtitle to copy")
                  return
              end

              mp.commandv("run", "${pkgs.wl-clipboard}/bin/wl-copy", subtitle)
              mp.osd_message("Copied subtitle: " .. subtitle)
          end

          -- Yank
          mp.add_key_binding("Ctrl+y", "copy-subtitle", copy_subtitle)
        '';
    };
  };
}
