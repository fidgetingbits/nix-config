{ ... }:
{
  # wayland.windowManager.hyprland.settings = {
  #
  #   #
  #   # ========== Layer Rules ==========
  #   #
  #   layer = [
  #     #"blur, rofi"
  #     #"ignorezero, rofi"
  #     #"ignorezero, logout_dialog"
  #
  #   ];
  #
  #   #
  #   # ========== layout rules ==========
  #   #
  #   dwindle = {
  #     preserve_split = true;
  #     pseudotile = true;
  #   };
  #
  #   #
  #   # ========== Window Rules ==========
  #   #
  #   windowrule = [
  #     #
  #     # ========== Workspace Assignments ==========
  #     #
  #     # to determine class and title for all active windows, run `hyprctl clients`
  #     # "match:class ^(obsidian)$, workspace 8"
  #     # "match:class ^(brave-browser)$, workspace 9"
  #     # "match:class ^(signal)$, workspace 9"
  #     # "match:class ^(discord)$, workspace 9"
  #     # "match:class ^(spotify)$, workspace 10"
  #     # "match:class ^(CopyQ)$, workspace 10"
  #     # "match:class ^(.virt-manager-wrapped)$, workspace 10"
  #     # "match:title ^(Proton VPN)$, workspace special"
  #     # "match:class ^(yubioath-flutter)$, workspace special"
  #     # "match:class ^(keymapp)$, workspace special"
  #
  #     #
  #     # ========== Tile on at launch ==========
  #     #
  #     "match:title ^(Proton VPN)$, tile on"
  #
  #     #
  #     # ========== float on at launch ==========
  #     #
  #     "match:class ^(galculator)$, float on"
  #
  #     # Dialog windows
  #     "match:title ^(Open File)(.*)$, float on"
  #     "match:title ^(Select a File)(.*)$, float on"
  #     "match:title ^(Choose wallpaper)(.*)$, float on"
  #     "match:title ^(Open Folder)(.*)$, float on"
  #     "match:title ^(Save As)(.*)$, float on"
  #     "match:title ^(Library)(.*)$, float on"
  #     "match:title ^(Accounts)(.*)$, float on"
  #     "match:title ^(Text Import)(.*)$, float on"
  #     "match:title ^(File Operation Progress)(.*)$, float on"
  #     #"match:title ^()$, match:class ^([Ff]irefox), float on, focus 0"
  #     "match:title ^()$, match:class ^([Ff]irefox), float on, no_initial_focus on"
  #
  #     #
  #     # ========== Always opaque ==========
  #     #
  #     "match:class ^([Gg]imp)$, opaque on"
  #     "match:class ^([Ff]lameshot)$, opaque on"
  #     "match:class ^([Ii]nkscape)$, opaque on"
  #     "match:class ^([Bb]lender)$, opaque on"
  #     "match:class ^([Oo][Bb][Ss])$, opaque on"
  #     "match:class ^([Ss]team)$, opaque on"
  #     "match:class ^([Ss]team_app_*)$, opaque on"
  #     "match:class ^([Vv]lc)$, opaque on"
  #     "match:title ^(btop)(.*)$, opaque on"
  #     "match:title ^(amdgpu_top)(.*)$, opaque on"
  #     "match:title ^(Dashboard | glass*)(.*), opaque on"
  #     "match:title ^(Live video from*)(.*)$, opaque on"
  #
  #     # Remove transparency from video
  #     "match:title ^(Netflix)(.*)$, opaque on"
  #     "match:title ^(.*YouTube.*)$, opaque on"
  #     "match:title ^(Picture-in-Picture)$, opaque on"
  #
  #     #
  #     # ========== Scratch rules ==========
  #     #
  #     #"workspace:^(special)$,size 80% 85%"
  #     #"workspace:^(special)$, center"
  #
  #     #
  #     # ========== Steam rules ==========
  #     #
  #     "match:title ^()$,match:class ^([Ss]team)$,min_size 1 1"
  #     "match:class ^([Ss]team_app_*)$,immediate on"
  #     "match:class ^([Ss]team_app_*)$,workspace 7"
  #     "match:class ^([Ss]team_app_*)$,monitor 0"
  #
  #     #
  #     # ========== Fameshot rules ==========
  #     #
  #     # flameshot currently doesn't have great wayland support so needs some tweaks
  #     #"match:class ^([Ff]lameshot)$,rounding 0"
  #     #"match:class ^([Ff]lameshot)$, noborder"
  #     #"match:class ^([Ff]lameshot)$, float on"
  #     #"match:class ^([Ff]lameshot)$, move 0 0"
  #     #"match:class ^([Ff]lameshot)$,suppressevent fullscreen"
  #     # FIXME: this one will definitely need revisiting for correct syntax after 0.53 but I don't have flameshot on right now
  #     #"${flameshot},monitor:DP-1"
  #   ];
  # };
}
