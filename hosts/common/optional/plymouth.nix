{ ... }:
{
  # Plymouth taken from https://github.com/slwst/dotfiles
  boot.plymouth = {
    enable = true;
    #theme = "rings";
    #themePackages = [ (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "rings" ]; }) ];
  };
  boot.kernelParams = [ "quiet" ]; # Shut up kernel output prior to password prompt
}
