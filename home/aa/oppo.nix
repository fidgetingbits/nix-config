{
  pkgs,
  lib,
  ...
}:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: after fixing user/home values in HM
      [
        "home/common/core"
        "home/common/core/nixos.nix"
        # FIXME: Make this automatic in hosts/common/users/default.nix eventually
        "home/aa/common/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "sops.nix"
          "ssh.nix"

          "audio-tools.nix"
          #"vscode.nix"
          "development"
          "helper-scripts"
          "xdg.nix"
          "gpg.nix"
          #"kitty.nix"
          #"wezterm.nix"
          "ghostty.nix"
          "media.nix"
          "networking/protonvpn.nix"
          "atuin.nix"

          "gnome"
          "gnome-terminal.nix"
          "fcitx5"

          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
        ])
    )
  );

  home.packages = builtins.attrValues {
    inherit (pkgs)
      openrgb-with-all-plugins # for controlling RGB devices
      ffmpeg # mp4 -> gif conversion, etc
      ;
  };

  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;
  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
