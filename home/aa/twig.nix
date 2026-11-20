{
  config,
  pkgs,
  lib,
  osConfig,
  # inputs,
  namespace,
  ...
}:
let
  # inherit (lib.custom.microvm) mapHostMicrovms;
in
{
  imports = map lib.custom.relativeToRoot (
    # FIXME: remove after fixing user/home values in HM
    [
      "home/common/core"
      "home/common/core/nixos.nix"
    ]
    ++
      # Optional common modules
      (map (f: "home/common/optional/${f}") [
        # Development
        # "llm/agents.nix"
        # "llm/utils.nix"
        "development"
        # "aws.nix"

        "audio-tools.nix"
        #"vscode"
        "helper-scripts"
        "sops.nix"
        "gpg.nix"
        #common/optional/kitty.nix
        "ghostty.nix"
        #common/optional/wezterm.nix
        # "gnome-terminal.nix"
        "media.nix"
        "graphics.nix"
        # "ebooks.nix"
        "networking/protonvpn.nix"
        # "atuin.nix"
        # "remmina.nix"
        "yazi.nix"

        # === Window Managers ===
        "desktop"

        # "fcitx5"
        # Maybe more role-specific stuff
        "document.nix" # document editing
        "gui-utilities.nix" # core for any desktop
        # "chat.nix"
        "reversing"
        "wine.nix"
      ])
  );

  home.packages =
    lib.attrValues {
      inherit (pkgs)
        # ntfs3g
        # immich-cli
        # claude-agent-acp
        ;
      inherit (pkgs.introdus)
        easylkb
        # cyberpower-pdu
        ;
      inherit (pkgs.unstable)
        # proton-authenticator
        ;
    }
    ++ [
      # inputs.nix-options-search.packages.${pkgs.stdenv.hostPlatform.system}.default
      (pkgs.long-rsync.overrideAttrs (_: {
        recipients = osConfig.hostSpec.email.olanAdmins;
        deliverer = osConfig.hostSpec.email.notifier;
        sshPort = osConfig.hostSpec.networking.ports.tcp.ssh;
      }))
    ];

  home.file.".config/nox/nox.toml".source = (pkgs.formats.toml { }).generate "config.toml" {
    # auto_refresh_cache = true;
    # cache_dir = "/home/aa/.cache/nox";
    # cache_duration = "1week";
    # enable_logging = true;
    # log_file = "/home/aa/.local/share/nox/nox.log";
    # log_level = "error";
    sources = [
      {
        name = "NixOS";
        url = "https://nixos.org/manual/nixos/stable/options";
        version_url = "https://nixos.org/manual/nixos/stable/";
      }
      {
        name = "NixOS Unstable";
        url = "https://nixos.org/manual/nixos/unstable/options";
        version_url = "https://nixos.org/manual/nixos/unstable/";
      }
      {
        name = "Home Manager";
        url = "https://nix-community.github.io/home-manager/options.xhtml";
        version_url = "https://nix-community.github.io/home-manager/";
      }
      {
        name = "Home Manager NixOS";
        url = "https://nix-community.github.io/home-manager/nixos-options.xhtml";
        version_url = "https://nix-community.github.io/home-manager/";
      }
      # {
      #   name = "Home Manager Nix-Darwin";
      #   url = "https://nix-community.github.io/home-manager/nix-darwin-options.xhtml";
      #   version_url = "https://nix-community.github.io/home-manager/";
      # }
      # {
      #   name = "Nix-Darwin";
      #   url = "https://nix-darwin.github.io/nix-darwin/manual/index.html";
      # }
      {
        name = "Nix Built-ins";
        url = "https://nix.dev/manual/nix/2.28/language/builtins.html";
      }
    ];
    use_cache = true;
  };

  # FIXME: Could setup some sort of auto-upload to immich for dumping into a specific folder
  # like https://github.com/kiriwalawren/dotnix/blob/2f8d698c88fdb8ed260be077f4b2bbd00fdb063b/modules/system/immich-upload.nix#L39
  sops.secrets = {

    # for systems that don't support yubikey, as well as microvms, etc
    "keys/ssh/ed25519" = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519";
    };
  };

  home.sessionVariables = {
    # This variable prevents the following from being spammed to the console constantly:
    # "MESA: warning: Support for this platform is experimental with Xe KMD, bug reports may be ignored."
    # See https://docs.mesa3d.org/envvars.html for details
    MESA_LOG_FILE = "/dev/null";
  };

  ${namespace} = {
    system.ssh-motd.enable = true;
    # FIXME: This needs to change
    llm.providers =
      let
        port = osConfig.hostSpec.networking.ports.tcp.llama-swap;
        hosts = [
          "oedo"
          "ossa"
        ];
      in
      map (host: {
        name = host;
        host = osConfig.hostSpec.networking.subnets.o-lan.hosts.${host}.ip;
        inherit port;
      }) hosts;

    llm.cli-tools.enable = true;
    dictation.enable = true;
  };

  stylix = {
    cursor = lib.mkForce {
      name = lib.mkForce "catppuccin-mocha-light-cursors";
      package = lib.mkForce pkgs.catppuccin-cursors.mochaLight;
      size = lib.mkForce 40;
    };
    targets.neovide.enable = true;
  };

  # Automatic ssh entries for oedo microvms on shared network
  # programs.ssh.settings =
  #   mapHostMicrovms inputs.self.nixosConfigurations.oedo.config.microvm.vms (vmSpecs: {
  #     "${vmSpecs.name}" = {
  #       match = "host ${vmSpecs.name}";
  #       hostname = vmSpecs.ip;
  #       port = vmSpecs.sshPort;
  #       inherit (vmSpecs) user;
  #       identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
  #     };
  #   })
  #   |> lib.mergeAttrsList;

  programs.firefox.package = pkgs.unstable.firefox;

}
