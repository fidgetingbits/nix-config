{ ... }:
{
  # Enable CUPS to print documents.
  services.printing.enable = true;
  # https://discourse.nixos.org/t/newly-announced-vulnerabilities-in-cups/52771
  #services.printing.browsed.enable = false;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
