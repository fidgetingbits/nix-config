# Good reference: https://github.com/upidapi/NixOs/blob/main/modules/home/apps/ghidra/default.nix
{
  lib,
  pkgs,
  config,
  ...
}:
let
  #ghidra_pkg = pkgs.unstable.ghidra.withExtensions (
  #  exts:
  #  builtins.attrValues {
  #    inherit (exts) ret-sync;
  #  }
  #);
  ghidra_dir = ".config/ghidra/${pkgs.unstable.ghidra.distroPrefix}";
in
{
  home = {
    # FIXME: Ghidra building is broken atm
    #packages = [ ghidra_pkg ];
    #packages = [ pkgs.unstable.ghidra ];
    # Searching public preferences is useful, since our own updates won't change this file
    # eg: https://github.com/antkss/dots-hypr/blob/2da60e3ac490ad262977df83702663668494d79f/.ghidra/.ghidra_11.0.3_PUBLIC/preferences#L2
    file = {
      "${ghidra_dir}/preferences".text = ''
        GhidraShowWhatsNew=false
        SHOW.HELP.NAVIGATION.AID=true
        SHOW_TIPS=false
        TIP_INDEX=0
        G_FILE_CHOOSER.ShowDotFiles=true
        Theme=File\:${pkgs.ghidra-gruvbox-theme}/gruvbox-dark-hard.theme
        USER_AGREEMENT=ACCEPT
        LastExtensionImportDirectory=${config.home.homeDirectory}/.config/ghidra/scripts/
        LastNewProjectDirectory=${config.home.homeDirectory}/.config/ghidra/repos/
        ViewedProjects=
        RecentProjects=
      '';
    };
  };
}
// (lib.optionalAttrs pkgs.stdenv.isLinux {
  systemd.user.tmpfiles.rules = [
    # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html
    "d %h/${ghidra_dir} 0700 - - -"
    "L+ %h/.config/ghidra/latest - - - - %h/${ghidra_dir}"
    "d %h/.config/ghidra/scripts 0700 - - -"
    "d %h/.config/ghidra/repos 0700 - - -"
  ];
})
