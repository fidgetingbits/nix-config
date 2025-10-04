# FIXME: Revisit whole file, copied from EmergentMind
{
  config,
  lib,
  pkgs,
  ...
}:
let
  commonDeps = with pkgs; [
    coreutils
    gnugrep
    systemd
  ];
  mkScript =
    {
      name ? "script",
      deps ? [ ],
      script ? "",
    }:
    lib.getExe (
      pkgs.writeShellApplication {
        inherit name;
        text = script;
        runtimeInputs = commonDeps ++ deps;
      }
    );
in
{
  home.packages = [
    pkgs.font-awesome
  ];

  # Needed to add these services even if packets are already installed so share
  # path to XDG_DATA_DIRS to correctly find the fonts despite font-awesome
  # being installed Prevents: [error] Item 'nm-applet': Could not find an icon
  # named 'nm-signal-50' and no pixmap given.
  services.network-manager-applet.enable = true;
  services.blueman-applet.enable = true;

  programs.waybar = {
    enable = true;
    #package = pkgs.unstable.waybar;
    systemd = {
      enable = true;
    };

    settings = {
      #
      # ========== Main Bar ==========
      #
      mainBar = {
        layer = "top";
        position = "top";
        height = 36; # 36 is the minimum height required by the modules
        #NOTE: Defining output here is problematic on laptops that may or may not have an external monitor plugged in.
        # If all potential monitors are defined here but not all of them are plugged in, waybar doesn't display on any monitor.
        # with `output` unspecified, waybar will output to all plugged in monitors
        #output = (map (m: "${m.name}") (config.monitors));

        modules-left = [
          "hyprland/workspaces"
        ];
        modules-center = [ "hyprland/window" ];
        modules-right =
          if config.hostSpec.isMobile then
            [
              #"gamemode"
              "tray"
              "pulseaudio"
              "battery"
              "backlight"
              "clock#time"
              "clock#date"
            ]
          else
            [
              #"gamemode"
              "tray"
              "pulseaudio"
              "clock#time"
              "clock#date"
            ];

        # ========= Modules =========
        #
        #TODO
        #"hyprland/window" ={};

        "hyprland/workspaces" = {
          all-outputs = false;
          disable-scroll = true;
          on-click = "activate";
          show-special = true; # display special workspaces along side regular ones (scratch for example)
        };
        "clock#time" = {
          interval = 1;
          format = "{:%H:%M}";
          tooltip = false;
        };
        "clock#date" = {
          interval = 10;
          format = "{:%d.%b.%y.%a}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        "gamemode" = {
          "format" = "{glyph}";
          "format-alt" = "{glyph} {count}";
          "glyph" = "";
          "hide-not-running" = true;
          "use-icon" = true;
          "icon-name" = "input-gaming-symbolic";
          "icon-spacing" = 4;
          "icon-size" = 20;
          "tooltip" = true;
          "tooltip-format" = "Games running: {count}";
        };
        "bluetooth" = {
          "format" = " {icon} ";
          "format-disabled" = "";
          "format-connected" = "{device_battery_percentage}% {icon}";
          "icon-size" = 30;
          "format-icons" = {
            "off" = "󰂲";
            "on" = "󰂯";
            "connected" = "󰂱";
          };
          "on-click" = "blueman-manager";
        };
        "network" = {
          "format-wifi" = "{essid} ({signalStrength}%) ";
          "format-ethernet" = "{ipaddr} ";
          "format-disconnected" = "Disconnected ⚠";
          "tooltip-format" =
            "{essid} {ipaddr}\n{ifname} via {gwaddr} {essid}\nUP:{bandwidthUpBits}mbps  DOWN:{bandwidthDownBits}mbps {signalStrength}";
          "on-click" = "nm-connection-editor";
        };
        "pulseaudio" = {
          "format" = "{volume}% {icon}";
          "format-source" = "Mic ON";
          "format-source-muted" = "Mic OFF";
          "format-bluetooth" = "{volume}% {icon}";
          "format-muted" = "";
          "format-icons" = {
            "alsa_output.pci-0000_00_1f.3.analog-stereo" = "";
            "alsa_output.pci-0000_00_1f.3.analog-stereo-muted" = "";
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "phone" = "";
            "phone-muted" = "";
            "portable" = "";
            "car" = "";
            "default" = [
              ""
              ""
            ];
          };
          "scroll-step" = 1;
          "on-click" = "pavucontrol";
          "ignored-sinks" = [ "Easy Effects Sink" ];
        };
        "backlight" = {
          tooltip = false;
          format = "{}% ";
          interval = 5;
          on-scroll-up = mkScript {
            deps = [ pkgs.brightnessctl ];
            script = "brightnessctl set 1%+";
          };
          on-scroll-down = mkScript {
            deps = [ pkgs.brightnessctl ];
            script = "brightnessctl set 1%-";
          };
        };
        "battery" = {
          states = {
            good = 95;
            warning = 30;
            critical = 20;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };
        #"mpd" = {
        #    "format" = "{stateIcon} {consumeIcon}{randomIcon}{repeatIcon}{singleIcon}{artist} - {album} - {title} ({elapsedTime:%M:%S}/{totalTime:%M:%S}) ";
        #    "format-disconnected" = "Disconnected ";
        #    "format-stopped" = "{consumeIcon}{randomIcon}{repeatIcon}{singleIcon}Stopped ";
        #    "interval" = 10;
        #    "consume-icons" = {
        #        "on" = " "; # Icon shows only when "consume" is on
        #    };
        #    "random-icons" = {
        #        "off" = "<span color=\"#f53c3c\"></span>"; #Icon grayed out when "random" is off
        #        "on" = " ";
        #    };
        #    "repeat-icons" = {
        #        "on" = " ";
        #    };
        #    "single-icons" = {
        #        "on" = "1 ";
        #    };
        #    "state-icons" = {
        #        "paused" = "";
        #        "playing" = "";
        #    };
        #    "tooltip-format" = "MPD (connected)";
        #    "tooltip-format-disconnected" = "MPD (disconnected)";
        #};
        "tray" = {
          spacing = 10;
        };
      };
    };
    #   style = ''
    #     * {
    #     	border: none;
    #     	border-radius: 0;
    #     	font-family: Font Awesome;
    #     	font-size: 14px;
    #     	min-height: 24px;
    #     }
    #   '';
  };
}
