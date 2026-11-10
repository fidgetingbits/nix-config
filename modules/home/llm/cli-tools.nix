{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.llm.cli-tools;
in
{
  options.${namespace}.llm.cli-tools = {
    enable = lib.mkEnableOption "Enable AI client cli tooling";
  };

  config = lib.mkIf cfg.enable {
    ${namespace}.llm.fabric.enable = true;
    home = {
      packages = lib.attrValues {
        inherit (pkgs.unstable)
          llama-cpp
          ;
        inherit (pkgs.unstable.python3Packages)
          huggingface-hub # hf cli tool
          ;
      };
    };

    programs = {
      # python cli tool for quick prompt-based outputs
      #  see ./llm-cli.nix
      llm = {
        enable = true;
      };
    };
  };

}
