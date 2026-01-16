{
  pkgs,
  lib,
  ...
}:
{
  imports = lib.map lib.custom.relativeToRoot [
    "modules/common"
    "hosts/common/core/ssh.nix"
    "hosts/common/users"
    "hosts/common/optional/minimal-user.nix"
  ];

  # Note, users will already be set by flake.nix
  hostSpec = {
    hostName = "installer";
    primaryUsername = "aa";
    persistFolder = "/persist";
    isMinimal = lib.mkForce true;
    domain = "local"; # Temporary domain for the installer
    email.admin = "example@example.com"; # Temporary for hosts using raid
  };

  fileSystems."/boot".options = [ "umask=0077" ]; # Removes permissions and security warnings.

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 10;
    # pick the highest resolution for systemd-boot's console.
    consoleMode = lib.mkDefault "max";
  };

  boot.initrd = {
    systemd.enable = true;
    systemd.emergencyAccess = true; # Don't need to enter password in emergency mode
    luks.forceLuksSupportInInitrd = true;
  };
  boot.kernelParams = [
    "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
    "systemd.show_status=true"
    #"systemd.log_level=debug"
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];

  # ssh-agent is used to pull my private secrets repo from github when deploying my nixos config.
  #programs.ssh.startAgent = true;

  # allow sudo over ssh with yubikey
  security.pam = {
    rssh.enable = true;
    services.sudo = {
      rssh = true;
      u2fAuth = true;
    };
  };

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      wget
      curl
      rsync
      git
      ;
  };

  networking = {
    networkmanager.enable = true;
  };

  services.openssh = {
    enable = true;
    ports = [ 10022 ];
    settings = {
      PermitRootLogin = "yes";
    };
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];
  system.stateVersion = "23.11";
}
