{ pkgs, ... }:
{
  home.packages = [ pkgs.proton-vpn ];
  programs.zsh.shellAliases = {
    disable-ipv6-leak = "nmcli con down pvpn-ipv6leak-protection";
  };
}
