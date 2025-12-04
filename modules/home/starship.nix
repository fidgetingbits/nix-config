# A heavily opinionated starship module

# Reference of how Starship maps to Base24 since it is only apparent when
# looking at the generated .toml and doesn't make use of the full palette

# Base[00] = starship color token
# -------------------------------
# Base00 = black
# Base01 =
# Base02 =
# Base03 = bright-black
# Base04 =
# Base05 = white
# Base06 =
# Base07 = bright-white
# Base08 = red
# Base09 = orange
# Base0A = yellow
# Base0B = green
# Base0C = cyan
# Base0D = blue
# Base0E = magenta or purple
# Base0F = brown
# Base10 =
# Base11 =
# Base12 = bright-red
# Base13 = bright-yellow
# Base14 = bright-green
# Base15 = bright-cyan
# Base16 = bright-blue
# Base17 = bright-magenta or bright-purple

{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.programs.starship;
in
{
  options.programs.starship = {
    left_divider_str = mkOption {
      type = types.str;
      example = "  ";
      default = "";
      description = "Character used for separating starship modules.";
    };
    right_divider_str = mkOption {
      type = types.str;
      example = "  ";
      default = "";
      description = "Character used for separating starship modules.";
    };
    fill_str = mkOption {
      type = types.str;
      example = "·";
      default = " ";
      description = "Character used for separating starship modules.";
    };
  };
  config = mkIf cfg.enable {
    programs.starship =
      let
        left_divider = "[${cfg.left_divider_str}](bg:base01 fg:white)";
        right_divider = "[${cfg.right_divider_str}](bg:base01 fg:white)";
      in
      {
        enableZshIntegration = true;
        enableTransience = true; # NOTE: transcience for zsh isn't support out-of-box but we enable at the end of this file
        settings = {
          add_newline = true;

          # some dressing characters for reference
          #╭─   admin@myth  ~ ▓▒░····░▒▓ 󰞑     19:44:14 ─╮
          #░▒▓
          #▓▒░
          #
          #
          format = ''
            [╭─](base0F)[](base01)$os${left_divider}$username$hostname${left_divider}$directory${left_divider}$git_branch$git_commit$git_state$git_metrics$git_status[▓▒░](base01)$fill[░▒▓](base01)$status$cmd_duration${right_divider}$nix_shell[](base01)[─╮](base0F)

          '';
          character = {
            format = "$symbol";
            success_symbol = "[❯](bold green)";
            error_symbol = "[❯](bold red)";
            vicmd_symbol = "[V](bold blue)";
            disabled = false;
          };
          cmd_duration = {
            format = "[$duration ]($style)";
            style = "bg:base01 fg:white";
            disabled = false;
            min_time = 250;
            show_milliseconds = false;
            show_notifications = false;
          };
          directory = {
            home_symbol = "~";
            truncation_length = 9;
            truncation_symbol = "…/";
            truncate_to_repo = false;

            format = "[$path ]($style)[$read_only ]($read_only_style)";
            style = "bold bg:base01 fg:blue";
            read_only_style = "bg:base01 fg:blue dimmed";

            repo_root_format = "[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path ]($style)[$read_only ]($read_only_style)";
            before_repo_root_style = "bg:base01 fg:blue";
            repo_root_style = "bold bg:base01 fg:blue";

            use_os_path_sep = true;
          };
          direnv = {
            disabled = false;
          };
          fill = {
            style = "bg:base00 fg:white";
            symbol = "${cfg.fill_str}";
          };
          git_branch = {
            format = "[$symbol$branch(:$remote_branch) ]($style)";
            symbol = "[ ](bg:base01 fg:green)";
            style = "bg:base01 fg:green";
          };
          git_status = {
            format = "($ahead_behind$staged$renamed$modified$untracked$deleted$conflicted$stashed)";
            style = "bg:base01 fg:green";

            conflicted = "[~$count ](bg:base01 fg:orange)";
            ahead = "[▲$count ](bg:base01 fg:green)";
            behind = "[▼$count ](bg:base01 fg:green)";
            diverged = "[◇[$ahead_count](bold bg:base01 fg:green)/[$behind_count ](bold bg:base01 fg:red) ](bg:base01 fg:orange)";
            untracked = "[?$count ](bg:base01 fg:yellow)";
            stashed = "[*$count ](bold bg:base01 fg:purple)";
            modified = "[!$count ](bg:base01 fg:yellow)";
            renamed = "[r$count ](bg:base01 fg:cyan)";
            staged = "[+$count ](bg:base01 fg:blue)";
            deleted = "[-$count ](bg:base01 fg:red)";
          };
          hostname = {
            disabled = false;
            ssh_only = true;
            format = "[@$hostname]($style)";
            style = "bg:base01 fg:purple";
          };
          nix_shell = {
            disabled = false;
            heuristic = false;
            format = "[  $symbol](bg:base01 fg:blue)";
            #symbol = " ";
          };
          os = {
            disabled = false;
            format = "[$symbol ]($style)";
            style = "bg:base01 fg:white";
          };
          # when enabled this indicates when sudo creds are cached or not
          # sudo = {
          #   format = "[$symbol]($style)";
          #   style = "red";
          #   symbol = "#";
          #   disabled = false;
          # ;
          time = {
            disabled = false;
            format = "[$time]($style)";
            style = "bg:base01 fg:brown";
            time_format = "%y.%m.%d{%H:%M:%S";
          };
          status = {
            #FIXME: add pipestatus symbols and styles
            disabled = false;
            format = "[$symbol]($style)";
            symbol = " ";
            success_symbol = "󰞑 ";
            not_executable_symbol = " ";
            not_found_symbol = " ";
            sigint_symbol = " ";
            #signal_symbol = "";
            success_style = "bg:base01 fg:green";
            failure_style = "bg:base01 fg:red";
          };
          username = {
            disabled = false;
            show_always = false;
            format = "[$user]($style)";
            style_user = "bg:base01 fg:purple";
            style_root = "bold bg:base01 fg:red";
          };
        };

      };
    # enable transient prompt for Zsh
    programs.zsh.initContent =
      lib.optionalString (config.programs.starship.enable && config.programs.starship.enableTransience)
        ''
          TRANSIENT_PROMPT=$(starship module character)

          function zle-line-init() {
          emulate -L zsh

          [[ $CONTEXT == start ]] || return 0
          while true; do
              zle .recursive-edit
              local -i ret=$?
              [[ $ret == 0 && $KEYS == $'\4' ]] || break
              [[ -o ignore_eof ]] || exit 0
          done

          local saved_prompt=$PROMPT
          local saved_rprompt=$RPROMPT

          PROMPT=$TRANSIENT_PROMPT
          zle .reset-prompt
          PROMPT=$saved_prompt

          if (( ret )); then
              zle .send-break
          else
              zle .accept-line
          fi
          return ret
          }
        '';
  };

}
