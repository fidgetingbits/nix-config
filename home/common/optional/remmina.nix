{ pkgs, ... }:
{
  # FIXME(remmina): To setup the module use ~/.local/share/remmina and ~/.config/remmina
  # First check github for other peoples modules though
  home.packages = [ pkgs.remmina ];
}
