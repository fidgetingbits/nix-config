{ pkgs, ... }:
{
  home.packages = [ pkgs.protonvpn-gui ];
  programs.zsh.shellAliases = {
    disable-ipv6-leak = "nmcli con down pvpn-ipv6leak-protection";
  };
}
