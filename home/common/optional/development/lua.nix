{ pkgs, lib, ... }:
{
  home.packages = lib.attrValues {
    inherit (pkgs)
      # FIXME(lua): We may move to vscode yinfei.luahelper plugin, in which case don't need this. This is currently here for
      # vscode plugin that uses stylua I guess.
      stylua
      ;
  };
}
