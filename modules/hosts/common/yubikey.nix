{
  config,
  pkgs,
  lib,
  isDarwin,
  ...
}:
let
  homeDirectory = config.hostSpec.home;
in
{
  options = {
    yubikey = {
      enable = lib.mkEnableOption "Enable yubikey support";
      identifiers = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (lib.types.either lib.types.int lib.types.str);
        description = "Attrset of Yubikey IDs";
        example = lib.literalExample ''
          {
            foo = 12345678;
            bar = 87654321;
          }
        '';
      };
      autoScreenUnlock = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Unlock screen on yubikey insert";
      };
      autoScreenLock = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Lock screen on yubikey removal";
      };
    };
  };
  config =
    let
      yubikey-up =
        let
          yubikeyIds = lib.concatStringsSep " " (
            lib.mapAttrsToList (name: id: "[${name}]=\"${builtins.toString id}\"") config.yubikey.identifiers
          );
        in
        pkgs.writeShellApplication {
          name = "yubikey-up";
          runtimeInputs = builtins.attrValues { inherit (pkgs) gawk yubikey-manager; };
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            serial=$(ykman list | awk '{print $NF}')
            # If it got unplugged before we ran, just don't bother
            if [ -z "$serial" ]; then
              exit 0
            fi

            declare -A serials=(${yubikeyIds})

            key_name=""
            for key in "''${!serials[@]}"; do
              if [[ $serial == "''${serials[$key]}" ]]; then
                key_name="$key"
              fi
            done

            if [ -z "$key_name" ]; then
              echo WARNING: Unidentified yubikey with serial "$serial" . Won\'t link an SSH key.
              exit 0
            fi

            echo "Creating links to ${homeDirectory}/id_$key_name"
            ln -sf "${homeDirectory}/.ssh/id_$key_name" ${homeDirectory}/.ssh/id_yubikey
            ln -sf "${homeDirectory}/.ssh/yubikeys/id_$key_name.pub" ${homeDirectory}/.ssh/id_yubikey.pub
          '';
        };
      yubikey-down = pkgs.writeShellApplication {
        name = "yubikey-down";
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          rm ${homeDirectory}/.ssh/id_yubikey
          rm ${homeDirectory}/.ssh/id_yubikey.pub
        '';
      };
    in
    lib.mkIf config.yubikey.enable {
      environment.systemPackages = lib.flatten [
        (builtins.attrValues {
          inherit (pkgs)
            gnupg
            pam_u2f # for yubikey with sudo
            yubikey-manager # For ykman
            ;
        })
        yubikey-up
        yubikey-down
      ];

      # Yubikey required services and config. See Dr. Duh NixOS config for
      # reference
      services = lib.optionalAttrs isDarwin {
        yubikey-agent.enable = true;

        udev.extraRules = lib.optionalString pkgs.stdenv.isLinux ''
          # Link/unlink ssh key on yubikey add/remove
          SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="1050", RUN+="${lib.getBin yubikey-up}/bin/yubikey-up"
          # NOTE: Yubikey 4 has a ID_VENDOR_ID on remove, but not Yubikey 5 BIO, whereas both have a HID_NAME.
          # Yubikey 5 HID_NAME uses "YubiKey" whereas Yubikey 4 uses "Yubikey", so matching on "Yubi" works for both
          SUBSYSTEM=="hid", ACTION=="remove", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${lib.getBin yubikey-down}/bin/yubikey-down"

          ##
          # Yubikey 4
          ##

          # Lock the device if you remove the yubikey (use udevadm monitor -p to debug)
          # #ENV{ID_MODEL_ID}=="0407", # This doesn't match all the newer keys
          # FIXME: We only want this to happen if we're undocked, so we need to see how that works. We probably need to run a
          # script that does smarter checks
          # ACTION=="remove",\
          #  ENV{ID_BUS}=="usb",\
          #  ENV{ID_VENDOR_ID}=="1050",\
          #  ENV{ID_VENDOR}=="Yubico",\
          #  RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

          ##
          # Yubikey 5 BIO
          #
          # NOTE: The remove event for the bio doesn't include the ID_VENDOR_ID for some reason, but we can use the
          # hid name instead. Some HID_NAME might be "Yubico YubiKey OTP+FIDO+CCID" or "Yubico YubiKey FIDO", etc so just
          # match on "Yubico YubiKey"
          ##

          # SUBSYSTEM=="hid",\
          #  ACTION=="remove",\
          #  ENV{HID_NAME}=="Yubico YubiKey FIDO",\
          #  RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

          # FIXME: Change this so it only wakes up the screen to the login screen, xset cmd doesn't work
          # SUBSYSTEM=="hid",\
          #  ACTION=="add",\
          #  ENV{HID_NAME}=="Yubico YubiKey FIDO",\
          #  RUN+="${pkgs.systemd}/bin/loginctl activate 1"
          #  #RUN+="${lib.getBin pkgs.xorg.xset}/bin/xset dpms force on"
        '';

        udev.packages = [ pkgs.yubikey-personalization ];
        pcscd.enable = true;
      }; # smartcard service

      # yubikey login / sudo
      security.pam = lib.optionalAttrs pkgs.stdenv.isLinux {
        u2f = {
          enable = true;
          settings = {
            cue = false; # Tells user they need to press the button
            authFile = "${homeDirectory}/.config/Yubico/u2f_keys";

          };
        };
        services = {
          login.u2fAuth = true;
          sudo = {
            u2fAuth = true;
          };
          # Attempt to auto-unlock gnome-keyring using u2f
          # NOTE: vscode uses gnome-keyring even if we aren't using gnome, which is why it's still here
          # This doesn't work
          #gnome-keyring = {
          #  text = ''
          #    session    include                     login
          #    session optional ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
          #  '';
          #};
        };
      };
    };
}
