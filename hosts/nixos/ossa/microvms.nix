{
  config,
  pkgs,
  lib,
  # inputs,
  namespace,
  ...
}:

let
  hostAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpB8D7hvlBLDbt936OljTdpNcT01pHYqnnZj5rpD+xF aa@ossa"
  ];
  lan = config.hostSpec.networking.subnets.agent-lan;
in
{
  ${namespace}.ai-agents.vms = {
    claude = {
      inherit (lan.hosts.claude) ip;
      mac = (lib.head lan.hosts.claude.mac);
      sshPort = 22;
      packages = [ pkgs.claude-code ];
      inherit hostAuthorizedKeys;
      extraConfig = { };
    };
    #  codex = {
    #   inherit (lan) mac ip;
    #   sshPort = 2202;
    #   package = pkgs.codex;
    # extraConfig = { };
    # };
    # gemini = {
    #   inherit (lan) mac ip;
    #   sshPort = 2203;
    #   package = pkgs.gemini-cli;
    # extraConfig = { };
    # };
    #
    # pi = {
    #   inherit (lan) mac ip;
    #   sshPort = 2204;
    #   package = pkgs.claude-code; # FIXME:
    #   # package = pkgs.pi;
    # extraConfig = { };
    # };
  };
}
