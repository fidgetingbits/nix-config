{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  imports =
    (map lib.custom.relativeToRoot (
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "helper-scripts"
          "sops.nix"
          "xdg.nix"
          "gpg.nix"
          "atuin.nix"
        ])
    ))
    ++ [
      # FIXME: Some weirdness. importing in modules/home/common/auto-styling.nix breaks actually styled systems even if they aren't importing this elsewhere? But not importing it on myth breaks the conditional
      inputs.stylix.homeModules.stylix
    ];

  home.packages =
    (lib.attrValues {
      inherit (pkgs)
        screen # Needed for serial console attached to server
        ;
    })
    # FIXME: Define this once in a file each system imports, with other backup utilities
    ++ [
      (pkgs.long-rsync.overrideAttrs (_: {
        recipients = osConfig.hostSpec.email.olanAdmins;
        deliverer = osConfig.hostSpec.email.notifier;
        sshPort = osConfig.hostSpec.networking.ports.tcp.ssh;
      }))
    ];

  system.ssh-motd.enable = true;
}
