{ config, pkgs, ... }:
{
  # cli tools that we want everywhere, not managed by home-manager
  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      fzf # Fuzzy search
      zoxide # Smarter cd
      tree # cli directory listing
      ripgrep # better grep
      findutils # find, xargs, locate, etc
      eza # better cat
      htop # better top
      cyme # better lsusb
      pciutils
      usbutils
      tokei
      curl
      wget
      jq
      mailutils
      direnv
      mlocate # locate

      # compression
      nix-output-monitor
      p7zip
      zip
      unzip
      unrar
      # security
      checksec
      ;
    inherit (pkgs.unstable)
      # cli tools
      bat # better cat
      ;
  };

  services.locate = {
    enable = true;
    package = pkgs.mlocate;

    pruneNames = [
      ".direnv"
      ".svn"
      ".hg"
      ".git"
      "cache"
      ".cache"
      ".cpcache"
      ".aot_cache"
      ".boot"
      "node_modules"
      ".cargo"
      "__pycache__"
    ];
    prunePaths = [
      "/dev"
      "/lost+found"
      "/nix/var"
      "/proc"
      "/run"
      "/sys"
      "/tmp"
      "/usr/tmp"
      "/var/tmp"
      "/mnt"
      "/var/lock"
      "/var/spool"
      "/nix/var/log/nix"
      "${config.hostSpec.home}/mount" # Don't index NAS mounts
      "${config.hostSpec.home}/backup" # Don't index backups
    ];
  };
}
