# Display a host-specific motd animation when sshing into a remote host
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  motd = pkgs.writeShellApplication {
    name = "motd";
    runtimeInputs = builtins.attrValues {
      inherit (pkgs)
        coreutils
        terminaltexteffects
        fastfetch
        chafa
        ;
    };
    text = ''
      #!/usr/bin/env bash
      D_WIDTH=80
      D_HEIGHT=20
      # FIXME: We could ensure the banners are small enough to not be stretched and just
      # let chafa auto scale it, but haven't done that for now
      # Check the terminal is wide enough to not botch the image
      if [ "$(tput cols)" -ge "$D_WIDTH" ]; then
        chafa --view-size "''${D_WIDTH}x$D_HEIGHT" -f ansi ${cfg.banner};
      fi
      fastfetch -c ${./config.jsonc}
    '';
  };
  cfg = config.system.ssh-motd;
in
{
  options.system.ssh-motd = {
    enable = lib.mkEnableOption "ssh motd";
    # FIXME: Make this a folder where you can cycle random entries
    banner = lib.mkOption {
      type = lib.types.path;
      default = "${inputs.nix-assets}/images/banners/generic.png";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [
      motd
    ];
    programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
      if [[ -n $SSH_CONNECTION ]]; then
        motd
      fi
    '';
  };
}
