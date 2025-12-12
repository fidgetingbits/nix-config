{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.llama;
in
{
  options = {
    services.llama = {
      enable = lib.mkEnableOption "Run llama AI services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-rocm;
      host = "0.0.0.0";
      openFirewall = true;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = "1h";
      };
    };
  };
}
