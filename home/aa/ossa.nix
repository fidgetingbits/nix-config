{
  config,
  pkgs,
  lib,
  osConfig,
  inputs,
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
          # Development
          "llm/agents.nix"
          "llm/utils.nix"
          "development"
          "aws.nix"

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
          "ebooks.nix"
          "networking/protonvpn.nix"
          "atuin.nix"
          "remmina.nix"
          "yazi.nix"

          # === Window Managers ===
          "desktop"

          "fcitx5"
          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
          "chat.nix"
          "reversing"
          "wine.nix"
        ])
    )
  );

  home.packages =
    lib.attrValues {
      inherit (pkgs)
        ntfs3g
        immich-cli
        claude-agent-acp
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
      inputs.nix-options-search.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    "keys/immich" = { };

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
    IMMICH_INSTANCE_URL = "https://immich.ooze.${osConfig.hostSpec.domain}";
  };

  programs.zsh.initContent =
    lib.mkAfter
      # bash
      ''
        export GITHUB_TOKEN=$(cat ${config.sops.secrets."tokens/github".path})
        export IMMICH_API_KEY=$(cat ${config.sops.secrets."keys/immich".path})
        export OPENAI_API_KEY=$(cat ${config.sops.secrets."tokens/openai".path})
        export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."tokens/anthropic".path})
        export GEMINI_API_KEY=$(cat ${config.sops.secrets."tokens/google".path})
        export NVIDIA_API_KEY=$(cat ${config.sops.secrets."tokens/nvidia".path})
        export LLAMA_SWAP_API_KEY="foo"
      '';

  # Using noctalia v5 now
  # introdus.services.awww = {
  #   enable = true;
  #   interval = lib.custom.time.days 1;
  #   wallpaperDir = "${config.home.homeDirectory}/images/wallpaper/catppuccin-mocha";
  # };

  # FIXME: Make this part of a module
  services.copyq.enable = true;

  system.ssh-motd.enable = true;

  stylix = {
    cursor = lib.mkForce {
      name = lib.mkForce "catppuccin-mocha-light-cursors";
      package = lib.mkForce pkgs.catppuccin-cursors.mochaLight;
      size = lib.mkForce 40;
    };
    targets.neovide.enable = true;
  };

  # https://github.com/FrameworkComputer/linux-docs/blob/87e682ee85eca8b74f5869458f8ffbebc714cb86/easy-effects/README.md?plain=1#L4
  # Official: https://raw.githubusercontent.com/FrameworkComputer/linux-docs/main/easy-effects/fw16-easy-effects.json
  services.easyeffects = {
    enable = true;
    preset = "easyeffects-fw16";
    extraPresets = {
      "easyeffects-fw16" =
        pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/FrameworkComputer/linux-docs/main/easy-effects/fw16-easy-effects.json";
          sha256 = "sha256-Te8S9DsG5P/NuNk5WE6mSB/DjHS+rKjOFRN7mDEVg8g=";
        }
        |> lib.readFile
        # nixfmt hack
        |> lib.fromJSON;
    };
  };

  ${namespace} = {
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
        inherit host port;
      }) hosts;

    llm.cli-tools.enable = true;
    language-learning.enable = true;
    dictation.enable = true;
  };

  # Automatic ssh entries for oedo microvms on shared network
  programs.ssh.settings =
    mapHostMicrovms inputs.self.nixosConfigurations.oedo.config.microvm.vms (vmSpecs: {
      "${vmSpecs.name}" = {
        match = "host ${vmSpecs.name}";
        hostname = vmSpecs.ip;
        port = vmSpecs.sshPort;
        user = vmSpecs.user;
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    })
    |> lib.mergeAttrsList;

  programs.anki.enable = true; # see module
  programs.firefox.package = pkgs.unstable.firefox;

  # catppuccin makes some fields unreadable for whatever reason
  stylix.targets.anki.enable = false;
}
