{
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

  home.file = {
    ".ssh/config.d/.keep".text = "# Managed by Home Manager";
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
  };
}
