# This file (and the global directory) holds config that I use on all hosts except nixos-installer.
# It imports foundation.nix as a base (which is used by nixos-installer) and builds on that for all hosts.
# IMPORTANT: This is used by NixOS and nix-darwin so options must exist in both!
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  platform = if isDarwin then "darwin" else "nixos";
  platformModules = "${platform}Modules";
in
{
  imports = lib.flatten [
    inputs.home-manager.${platformModules}.home-manager
    inputs.sops-nix.${platformModules}.sops
    inputs.disko.${platformModules}.disko
    inputs.nix-index-database.${platformModules}.nix-index
    { programs.nix-index-database.comma.enable = true; }

    (map lib.custom.relativeToRoot [
      "modules/common/"
      "modules/hosts/common"
      "modules/hosts/${platform}"

      "hosts/common/core/sops.nix" # Core because it's used for backups, mail
      "hosts/common/core/ssh.nix"
      "hosts/common/core/${platform}.nix"
      "hosts/common/users/primary"
      "hosts/common/users/primary/${platform}.nix"
    ])
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = [
      inputs.talon-nix.overlays.default
      outputs.overlays.default
    ];
  };

  networking.hostName = config.hostSpec.hostName;

  # System-wide packages, in case we log in as root
  environment.systemPackages = [ pkgs.openssh ];

  # Force home-manager to use global packages
  # FIXME: This is broken when using home-manager overlays, so need to remove above overlays?
  home-manager.useGlobalPkgs = true;
  # If there is a conflict file that is backed up, use this extension
  home-manager.backupFileExtension = "bk";
  # home-manager.useUserPackages = true;

  # On darwin it's important this is outside home-manager
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "source ''${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  };

  # Probably use knownHostsFiles to add some extra secrets rather than spell them all out
  # Modern entries are hashed:
  # https://security.stackexchange.com/questions/56268/ssh-benefits-of-using-hashed-known-hosts
  # https://serverfault.com/questions/331080/what-do-the-different-parts-of-known-hosts-entries-mean
  # We should hash them ourselves as part of this
  # Format:
  # |1|F1E1KeoE/eEWhi10WpGv4OdiO6Y=|3988QV0VE8wmZL7suNrYQLITLCg= ssh-rsa ...
  # |1| - Means it's hashed
  # F1E1KeoE/eEWhi10WpGv4OdiO6Y= - Salt
  # 3988QV0VE8wmZL7suNrYQLITLCg= - Hash
  # ssh-rsa ... - The rest of the line
  # builtins.hashString
  # This is Linux only?

  hostSpec = {
    username = "aa";
    handle = "fidgetingbits";
    inherit (inputs.nix-secrets)
      domain
      email
      userFullName
      networking
      work
      ;
  };

  # FIXME(darwin): I'm not sure this works on darwin...
  security.pki.certificates = lib.flatten (
    lib.optional config.hostSpec.isWork inputs.nix-secrets.work.certificates
  );
}
