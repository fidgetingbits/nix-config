{
  config,
  pkgs,
  lib,
  ...
}:
{
  # cli tools that we want everywhere, not managed by home-manager
  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      fzf # fuzzy search
      zoxide # smarter cd
      tree # tree-based directory listing
      ripgrep # better grep
      findutils # find, xargs, etc
      eza # better ls
      htop # better top
      cyme # better lsusb
      pciutils # lspci
      usbutils # lsusb
      tokei # code lines summary
      curl # cli http utility
      wget # cli http utility
      jq # json query tool
      jtbl # json table output
      mailutils
      direnv # develoment environment utility
      mlocate # locate
      wakeonlan # utility for WoL

      nix-output-monitor # better nix output

      # compression
      p7zip
      zip
      unzip
      unrar

      # security
      checksec
      ;
    inherit (pkgs.unstable)
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
