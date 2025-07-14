{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
# FIXME(organize): Try to get ryan4yin's way working with genPlatformArgs eventually
{
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;
    mutableExtensionsDir = true;
    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = (import ./extensions.nix { inherit inputs pkgs; });
      userSettings = (import ./settings.nix { inherit config lib pkgs; });
      keybindings = (import ./keybindings.nix);
    };
  };

  # Prevent keystore errors
  home.file.".vscode/argv.json" = {
    force = true;
    text = ''
      {
      	// "disable-hardware-acceleration": true,
      	"enable-crash-reporter": false,
      	// Unique id used for correlating crash reports sent from this instance.
      	// Do not edit this value.
      	"crash-reporter-id": "e9dfe01e-e6e1-4237-b2f2-a153ad5e5aa0",
        "password-store": "gnome",
        "force-renderer-accessibility": false
      }
    '';
  };
  # This is to prevent a bug with extensions being disabled when rebuilding nix with a new extension
  home.file.".vscode/extensions/.obsolete" = {
    force = true;
    text = ''{}'';
  };

  # FIXME(vscode): add an xdg-open override for opening inside the current vscode instance
  # https://github.com/tljuniper/dotfiles/blob/635635ed7c2eaf1a543081f452a5c0953db91ae7/home/desktop/vscode.nix#L152

}
