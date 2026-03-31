{
  pkgs,
  lib,
  # config,
  ...
}:
{
  imports = lib.map lib.custom.relativeToRoot [
    "modules/common"
    "hosts/common/core/ssh.nix"
    "hosts/common/users"
    "hosts/common/optional/minimal-user.nix"
    # It'll always be me reinstalling, so always use my bindings
    "hosts/common/optional/keyd.nix"
    "modules/hosts/nixos/remote-luks-unlock/"
    "modules/hosts/nixos/impermanence"
  ];

  # Note, users will already be set by flake.nix
  hostSpec = {
    isMinimal = lib.mkForce true;
    isAutoStyled = lib.mkForce false;
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

  # Allow ssh unlock for minimal installs
  services.remoteLuksUnlock = {
    enable = true;
    ssh = {
      users = [ "root" ];
      port = 10022;
    };
    notify.enable = false;
  };

  boot.kernelParams = [
    "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
    "systemd.show_status=true"
    #"systemd.log_level=debug"
    "systemd.log_target=console"
    "systemd.journald.forward_to_console=1"
  ];

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
