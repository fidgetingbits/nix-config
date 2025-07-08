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

      "hosts/common/users"
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

  # If there is a conflict file that is backed up, use this extension
  home-manager.backupFileExtension = "bk";
  # home-manager.useUserPackages = true;

  # On darwin it's important this is outside home-manager
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "source ''${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  };

  hostSpec = {
    primaryUsername = "aa";
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
