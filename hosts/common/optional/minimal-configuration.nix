{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  useWpaSupplicant = config.hostSpec.isRoaming && (!config.hostSpec.isRemote);
in
{
  imports = (
    lib.map lib.custom.relativeToRoot [
      "modules/hosts/common"
      "hosts/common/core/ssh.nix"
      "hosts/common/users"
      "hosts/common/optional/minimal-user.nix"
      # It'll always be me reinstalling, so always use my bindings
      "hosts/common/optional/keyd.nix"
      "modules/hosts/nixos/remote-luks-unlock/"
      "modules/hosts/nixos/impermanence"

    ]
    ++ [
      inputs.introdus.nixosModules.default
    ]
  );

  config = lib.mkMerge [
    {
      introdus.autoModules = false;

      # Note, users will already be set by flake.nix
      hostSpec = {
        isMinimal = lib.mkForce true;
        isAutoStyled = lib.mkForce false;
        useAtticCache = lib.mkForce false;
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
          wpa_supplicant
          ;
      };

      networking = {
        networkmanager.enable = (useWpaSupplicant == false);
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
    # FIXME: This doesn't work yet, because /etc/wpa_supplicant doesn't work...
    (lib.mkIf useWpaSupplicant {

      networking.wireless = {
        enable = true;
        allowAuxiliaryImperativeNetworks = true;
        extraConfig = lib.readFile (lib.custom.relativeToRoot "secrets/wpa_supplicant-olan.conf");
      };

      systemd.network.enable = true;
      systemd.network.networks."10-wlan-dhcp" = {
        matchConfig.Type = "wlan";
        networkConfig.DHCP = "yes";
      };
    })
  ];
}
