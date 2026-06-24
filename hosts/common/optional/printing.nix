{ pkgs, ... }:
{
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      postscript-lexmark
      lexmark-aex
    ];
  };

  # https://discourse.nixos.org/t/newly-announced-vulnerabilities-in-cups/52771
  #services.printing.browsed.enable = false;
  services.ipp-usb.enable = true;

  # For network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
