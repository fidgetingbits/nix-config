{
  inputs,
  config,
  pkgs,
  lib,
  osConfig,
  namespace,
  ...
}:
let
  inherit (lib.custom.microvm) mapHostMicrovms;
in
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: remove after fixing user/home values in HM
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "audio-tools.nix"
          #"vscode"
          "development"
          "aws.nix"
          "helper-scripts"
          "sops.nix"
          "gpg.nix"
          "ghostty.nix"
          "gnome-terminal.nix"
          "media.nix"
          "graphics.nix"
          "ebooks.nix"
          "networking/protonvpn.nix"
          "atuin.nix"
          "remmina.nix"
          "yazi.nix"

          # === Window Managers ===
          "desktop/"

          "fcitx5"
          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
          "chat.nix"
          "reversing"
          # "wine.nix"
        ])
    )
  );

  ${namespace}.llm.cli-tools.enable = true;

  home.packages =
    lib.attrValues {
      inherit (pkgs)
        ntfs3g
        ;
      inherit (pkgs.introdus)
        easylkb
        cyberpower-pdu
        ;
      inherit (pkgs.unstable)
        proton-authenticator
        ;
    }
    ++ [
      (pkgs.long-rsync.overrideAttrs (_: {
        recipients = osConfig.hostSpec.email.olanAdmins;
        deliverer = osConfig.hostSpec.email.notifier;
        sshPort = osConfig.hostSpec.networking.ports.tcp.ssh;
      }))
    ];

  home.sessionVariables = {
    # This variable prevents the following from being spammed to the console constantly:
    # "MESA: warning: Support for this platform is experimental with Xe KMD, bug reports may be ignored."
    # See https://docs.mesa3d.org/envvars.html for details
    MESA_LOG_FILE = "/dev/null";
  };

  system.ssh-motd.enable = true;

  stylix = {
    cursor = lib.mkForce {
      name = lib.mkForce "catppuccin-mocha-light-cursors";
      package = lib.mkForce pkgs.catppuccin-cursors.mochaLight;
      size = lib.mkForce 40;
    };
    targets.neovide.enable = true;
  };

  # Automatic ssh entries for oedo/ossa microvms on shared network
  programs.ssh.settings =
    [
      "oedo"
      "ossa"
    ]
    |> map (
      host:
      (
        mapHostMicrovms inputs.self.nixosConfigurations.${host}.config.microvm.vms (vmSpecs: {
          "${vmSpecs.name}" = {
            match = "host ${vmSpecs.name}";
            hostname = vmSpecs.ip;
            port = vmSpecs.sshPort;
            user = vmSpecs.user;
            identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
          };
        })
        |> lib.mergeAttrsList
      )
    )
    |> lib.mergeAttrsList;
}
