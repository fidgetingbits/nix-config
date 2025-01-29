{ pkgs, ... }:

let
  # Create a minimal NixOS system with Headscale
  nixos = pkgs.nixos (
    { ... }:
    {
      imports = [
        (pkgs.path + "/nixos/modules/services/networking/headscale.nix")
      ];

      services.headscale = {
        enable = true;
        address = "0.0.0.0";
        port = 8080;
        settings = {
          server_url = "https://headscale.example.com";
          db_path = "/var/lib/headscale/db.sqlite";
        };
      };
    }
  );

  # Extract the configured Headscale package and config
  #headscaleConfig = nixos.config.services.headscale.configFile;

in
pkgs.dockerTools.buildLayeredImage {
  name = "headscale";
  tag = "latest";

  contents = [
    nixos.config.services.headscale.package
    pkgs.bash
  ];

  extraCommands = ''
    mkdir -p etc/headscale
    cp ${headscaleConfig} etc/headscale/config.yaml
    mkdir -p var/lib/headscale
  '';

  config = {
    Cmd = [
      "${nixos.config.services.headscale.package}/bin/headscale"
      "serve"
      "--config"
      "/etc/headscale/config.yaml"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
    };
    Volumes = {
      "/var/lib/headscale" = { };
    };
  };
}
