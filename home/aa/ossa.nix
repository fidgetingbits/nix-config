{
  config,
  pkgs,
  lib,
  osConfig,
  inputs,
  ...
}:
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

  llm-tools.enable = true;

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
      inputs.optnix.packages.${pkgs.stdenv.hostPlatform.system}.optnix
      (pkgs.long-rsync.overrideAttrs (_: {
        recipients = osConfig.hostSpec.email.olanAdmins;
        deliverer = osConfig.hostSpec.email.notifier;
        sshPort = osConfig.hostSpec.networking.ports.tcp.ssh;
      }))
    ];

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
        export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."tokens/claude".path})
      '';

  introdus.services.awww = {
    enable = true;
    interval = lib.custom.time.days 1;
    wallpaperDir = "${config.home.homeDirectory}/images/wallpaper/catppuccin-mocha";
  };

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

}
