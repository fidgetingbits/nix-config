{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./yubikey.nix ];
  # From tlater config, but config comes from Dr Duh. tutorial
  programs.gpg = {
    enable = true;
    homedir = "${config.xdg.dataHome}/gnupg";
    settings = {
      fixed-list-mode = true;
      keyid-format = "0xlong";
      personal-digest-preferences = builtins.concatStringsSep " " [
        "SHA512"
        "SHA384"
        "SHA256"
      ];
      personal-cipher-preferences = builtins.concatStringsSep " " [
        "AES256"
        "AES192"
        "AES"
      ];
      default-preference-list = builtins.concatStringsSep " " [
        "SHA512"
        "SHA384"
        "SHA256"
        "AES256"
        "AES192"
        "AES"
        "ZLIB"
        "BZIP2"
        "ZIP"
        "Uncompressed"
      ];
      # use-agent = true;
      verify-options = "show-uid-validity";
      list-options = "show-uid-validity";
      cert-digest-algo = "SHA512";
      throw-keyids = false;
      no-emit-version = true;
    };

    scdaemonSettings.disable-ccid = true;
    publicKeys = [
      # github.com 2024-01-16 commit signing key
      {
        text = lib.readFile (
          pkgs.fetchurl rec {
            name = "web-flow.gpg";
            url = "https://github.com/${name}";
            hash = "sha256-bor2h/YM8/QDFRyPsbJuleb55CTKYMyPN4e9RGaj74Q=";
          }
        );

        trust = "ultimate";
      }
      # github.com 2017-08-16 commit signing key
      {
        text = lib.readFile (
          pkgs.fetchurl rec {
            name = "web-flow.gpg";
            url = "https://web.archive.org/web/20240123210723/https://github.com/${name}";
            hash = "sha256-bor2h/YM8/QDFRyPsbJuleb55CTKYMyPN4e9RGaj74Q=";
          }
        );

        trust = "ultimate";
      }
    ];
  };

  # From mikilio
  #integration with pam services (unlock gpg after login)
  home.file.".pam-gnupg".text = ''
    ${config.programs.gpg.homedir}
  '';

  home = {
    sessionVariables.GPG_TTY = "$(tty)";
  };

  # services = {
  #   gpg-agent = {
  #     enable = true;
  #     enableSshSupport = true;
  #     pinentryFlavor = "gnome3";
  #     sshKeys = [ ];
  #     defaultCacheTtl = 54000;
  #     maxCacheTtl = 54000;

  #     extraConfig = ''
  #       debug-pinentry
  #       debug-level 1024
  #     '';
  #   };
  # };
}
